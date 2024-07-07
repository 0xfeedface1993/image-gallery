import SwiftUI
import URLImageStore
import URLImage
import OSLog

public protocol ImageProvider {
    var url: URL { get }
}

extension URL: ImageProvider {
    public var url: URL {
        self
    }
}

public enum UserGestureState {
    case start
    case change
    case end
}

enum UserAction {
    case tap(location: Point, layoutOptions: LayoutOptions)
    case doubleTap(location: Point)
    case doubleTapOutside
    case drag(translation: Size, state: UserGestureState, layoutOptions: LayoutOptions)
    case scale(location: Point, magnification: Double, state: UserGestureState, layoutOptions: LayoutOptions)
    case rotate(location: Point, angle: Angle, state: UserGestureState, layoutOptions: LayoutOptions)
    case move(Size)
}

public struct GestureEvent {
    public let item: ImageProvider
    public let states: [StateChange]
}

extension GestureEvent {
    public enum Gesture {
        case scale(Double)
        case rotate(Angle)
        case move(CGSize)
    }
    
    public struct StateChange {
        public let change: Gesture
        public let state: UserGestureState
    }
}

public enum Events {
    case tap(ImageProvider?)
    case doubleTap(ImageProvider)
    case gestures(GestureEvent)
    case deviceOrientationChange(ImageProvider)
    case moveToPage(ImageProvider)
}

fileprivate let logger = Logger(subsystem: "UI", category: "ImageGallrey")

public struct ImagesGallary<Content: View>: View {
    @StateObject private var model: GallrayViewModel
    @State private var offset: Double
    @State private var deviceOrientationChange = false
    @State private var currentImage: GallrayViewModel.Item?
    @Environment(\.galleryOptions) private var galleryOptions
    
    private var attachedView: (ImageProvider, ImageLayoutDiscription) -> Content
    
    public var events: ((Events) -> Void)?
    
    public var tapBackIcon: (() -> Void)?
    
    public init(images: [ImageProvider], @ViewBuilder attached: @escaping (ImageProvider, ImageLayoutDiscription) -> Content, events: ((Events) -> Void)? = nil, tapBackIcon: (() -> Void)? = nil) {
        self.offset = .zero
        let viewModel = GallrayViewModel(images)
        self._model = StateObject(wrappedValue: viewModel)
        self.tapBackIcon = tapBackIcon
        self.events = events
        self.attachedView = attached
    }
    
    public var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .center, spacing: 0) {
                ForEach(model.images, id: \.url) { image in
                    ImageNodeView(item: image, attachView: { item, discription in
                        attachedView(item.metadata, discription)
                    })
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .opacity(image.url == currentImage?.url ? 1.0:0.6)
                    .zIndex(image.url == currentImage?.url ? 100:0)
                }
            }
            .frame(width: proxy.size.width * CGFloat(max(model.images.count, 1)))
            .background(Color.black.ignoresSafeArea())
            .offset(x: proxy.size.width * offset)
            .gesture(
                TapGesture()
                    .onEnded({ location in
                        model.send(.tap(location: .zero, layoutOptions: galleryOptions))
                        events?(.tap(model.currentImage?.metadata))
                    })
            )
            .simultaneousGesture(
                DragGesture(coordinateSpace: .local)
                    .onChanged { value in
                        guard galleryOptions.capability.contains(.dragging) else {
                            return
                        }
                        model.send(
                            .drag(translation: proxy.size.size.normalized(value.translation.size), state: .change, layoutOptions: galleryOptions)
                        )
                        if let image = model.currentImage {
                            events?(
                                .gestures(
                                    .init(item: image.metadata, states: [
                                        .init(change: .move(.init(width: model.unionOffset.x, height: model.unionOffset.y)), state: .change)
                                    ])
                                )
                            )
                        }
                    }
                    .onEnded { value in
                        guard galleryOptions.capability.contains(.dragging) else {
                            return
                        }
                        model.send(
                            .drag(translation: proxy.size.size.normalized(value.translation.size), state: .end, layoutOptions: galleryOptions)
                        )
                        if let image = model.currentImage {
                            events?(
                                .gestures(
                                    .init(item: image.metadata, states: [
                                        .init(change: .move(.init(width: model.unionOffset.x, height: model.unionOffset.y)), state: .end)
                                    ])
                                )
                            )
                        }
                    }
            )
            .onChange(of: model.unionOffset) { newValue in
                let x = newValue.x
                let update = offset != x
                guard update else {
                    return
                }
                withAnimation(.spring().speed(1.5)) {
                    offset = x
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification), perform: { _ in
                deviceOrientationChange.toggle()
            })
            .onChange(of: deviceOrientationChange, perform: { _ in
                offset = Double(-model.page)
                model.reset()
                if let image = model.currentImage {
                    events?(.deviceOrientationChange(image.metadata))
                }
            })
            .onChange(of: model.unionOffset, perform: { newValue in
                let page = model.indexOf(model.predictPageableOffset(newValue).x)
                guard model.images.startIndex <= page, page < model.images.endIndex else {
                    return
                }
                let image = model.images[page]
                events?(.moveToPage(image.metadata))
                withAnimation(.smooth) {
                    currentImage = image
                }
            })
        }
        .overlayed {
            if galleryOptions.panelEnable {
                DefaultPanelView(model: model, onTapBack: {
                    tapBackIcon?()
                })
            }
        }
        .environment(\.events, { value in
            events?(value)
        })
        .once {
            currentImage = model.currentImage
        }
    }
}

#Preview {
    ImagesGallary(images: [
        URL(string: "https://images.duanlndzi.bar/ecdb7c18e93fc76d336a787b7e357de5.jpg")!,
        URL(string: "https://images.duanlndzi.bar/1f004901f2efc537f58733b2253ecb9e.jpg")!
    ], attached: { _, _ in
        
    })
    .environment(\.urlImageService, URLImageService(fileStore: nil, inMemoryStore: URLImageInMemoryStore()))
}

