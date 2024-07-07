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

enum UserGestureState {
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

fileprivate let logger = Logger(subsystem: "UI", category: "ImageGallrey")

public struct ImagesGallary: View {
    @StateObject private var model: GallrayViewModel
    @State private var offset: Double
    @State private var deviceOrientationChange = false
    @State private var currentImage: GallrayViewModel.Item?
    @Environment(\.galleryOptions) private var galleryOptions
    
    public var tapBackIcon: (() -> Void)?
    
    public init(images: [ImageProvider], tapBackIcon: (() -> Void)? = nil) {
        self.offset = .zero
        let viewModel = GallrayViewModel(images)
        self._model = StateObject(wrappedValue: viewModel)
        self.tapBackIcon = tapBackIcon
    }
    
    public var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .center, spacing: 0) {
                ForEach(model.images, id: \.url) { image in
                    ImageNodeView(item: image)
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
                    })
            )
            .simultaneousGesture(
                DragGesture(coordinateSpace: .local)
                    .onChanged { value in
                        guard galleryOptions.capability.contains(.dragging) else {
                            return
                        }
                        model.send(
                            .drag(translation: proxy.size.size.normalization(value.translation.size), state: .change, layoutOptions: galleryOptions)
                        )
                    }
                    .onEnded { value in
                        guard galleryOptions.capability.contains(.dragging) else {
                            return
                        }
                        model.send(
                            .drag(translation: proxy.size.size.normalization(value.translation.size), state: .end, layoutOptions: galleryOptions)
                        )
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
            })
            .onChange(of: model.unionOffset, perform: { newValue in
                let page = model.indexOf(model.predictPageableOffset(newValue).x)
                withAnimation(.smooth) {
                    currentImage = model.images[page]
                }
            })
        }
        .overlayed {
            DefaultPanelView(model: model, onTapBack: {
                tapBackIcon?()
            })
        }
        .once {
            currentImage = model.currentImage
        }
    }
}

#Preview {
    ImagesGallary(images: [
        URL(string: "https://images.duanlndzi.bar/ecdb7c18e93fc76d336a787b7e357de5.jpg")!,
        URL(string: "https://images.duanlndzi.bar/1f004901f2efc537f58733b2253ecb9e.jpg")!
    ])
    .environment(\.urlImageService, URLImageService(fileStore: nil, inMemoryStore: URLImageInMemoryStore()))
}

