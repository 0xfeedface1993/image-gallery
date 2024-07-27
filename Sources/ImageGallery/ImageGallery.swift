import SwiftUI
import URLImageStore
import URLImage
import OSLog
import Core
import ScreenOut

fileprivate let logger = Logger(subsystem: "UI", category: "ImageGallrey")

public struct ImagesGallaryProgressView: View {
    public var images: [ImageProvider]
    public var startSelectedImage: Int
    @Environment(\.animateProgress) private var animateProgress: Double
    public var events: ((Events) -> Void)?
    public var tapBackIcon: (() -> Void)?
    @Namespace private var namespace
    
    public init(images: [ImageProvider], selectedImage: Int = 0, events: ((Events) -> Void)? = nil, tapBackIcon: (() -> Void)? = nil) {
        self.images = images
        self.tapBackIcon = tapBackIcon
        self.events = events
        self.startSelectedImage = selectedImage
    }
    
    public var body: some View {
//        ZStack {
//            ImagesGallaryWrapper(images: images, selectedImage: startSelectedImage, attached: { _, _ in }, events: events, tapBackIcon: tapBackIcon)
//                .opacity(animateProgress >= 1.0 ? 1:0)
//            
//            if images.count > 0, animateProgress < 1.0 {
//                URLImage(startSelectedImage < images.endIndex ? images[startSelectedImage].url:images.first!.url) { image in
//                    image.resizable()
//                        .aspectRatio(contentMode: .fit)
//                }
//            }
//        }
        if animateProgress >= 1 {
            ImagesGallaryWrapper(images: images, selectedImage: startSelectedImage, attached: { _, _ in }, events: events, tapBackIcon: tapBackIcon)
        } else {
            if images.count > 0 {
                URLImage(startSelectedImage < images.endIndex ? images[startSelectedImage].url:images.first!.url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fit)
                }                
            }
        }
    }
}

public struct ImagesGallaryView: View {
    public var images: [ImageProvider]
    public var startSelectedImage: Int
    public var events: ((Events) -> Void)?
    public var tapBackIcon: (() -> Void)?
//    @EnvironmentObject private var sharedState: GestureShareState
//    @StateObject private var defaultState = GestureShareState()
    
    public init(images: [ImageProvider], selectedImage: Int = 0, events: ((Events) -> Void)? = nil, tapBackIcon: (() -> Void)? = nil) {
        self.images = images
        self.tapBackIcon = tapBackIcon
        self.events = events
        self.startSelectedImage = selectedImage
    }
    
    public var body: some View {
        ImagesGallaryWrapper(images: images, selectedImage: startSelectedImage, attached: { _, _ in }, events: events, tapBackIcon: tapBackIcon)
    }
}

public struct ImagesGallaryWrapper<Content: View>: View {
    @StateObject private var model: GallrayViewModel
    @State private var offset: Double
    @State private var deviceOrientationChange = false
//    @State private var currentImage: GallrayViewModel.Item?
    private var startSelectedImage: Int
    private var startImages: [ImageProvider]
    @Environment(\.galleryOptions) private var galleryOptions
    @Environment(\.coverBackgroundColor) private var coverBackgroundColor
    @Environment(\.animateProgress) private var animateProgress
//    @State private var enableScreenOut: Bool = false
    @EnvironmentObject private var sharedState: GestureShareState
    
    private var attachedView: (ImageProvider, ImageLayoutDiscription) -> Content
    
    public var events: ((Events) -> Void)?
    
    public var tapBackIcon: (() -> Void)?
    
    public init(images: [ImageProvider], selectedImage: Int = 0, @ViewBuilder attached: @escaping (ImageProvider, ImageLayoutDiscription) -> Content, events: ((Events) -> Void)? = nil, tapBackIcon: (() -> Void)? = nil) {
        let viewModel = GallrayViewModel(images)
        viewModel.move(to: selectedImage)
        self._model = StateObject(wrappedValue: viewModel)
        self.offset = viewModel.unionOffset.x
//        self.currentImage = viewModel.currentImage
        self.tapBackIcon = tapBackIcon
        self.events = events
        self.attachedView = attached
        self.startImages = images
        self.startSelectedImage = selectedImage
    }
    
    public var body: some View {
//        let _ = Self._printChanges()
        GeometryReader { proxy in
            LazyHStack(alignment: .center, spacing: 0) {
                ForEach(model.images, id: \.url) { image in
                    if model.isDipslayWindow(image) {
                        ImageNodeView(item: image, attachView: { item, discription in
                            attachedView(item.metadata, discription)
                        })
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .zIndex(image.url == model.currentImage?.url ? 1:0)
                    } else {
                        Color.clear.frame(width: proxy.size.width, height: proxy.size.height)
                    }
                    //                    .opacity(image.url == currentImage?.url ? 1.0:0.6)
//                    .zIndex(image.url == currentImage?.url ? 100:0)
                }
            }
            .background(content: {
                coverBackgroundColor.ignoresSafeArea()
            })
            .frame(width: proxy.size.width * CGFloat(max(model.images.count, 1)))
            .offset(x: proxy.size.width * offset)
//            .preference(key: ScreenOutControlKey.self, value: enableScreenOut)
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
                        
                        let current = model.currentImage
                        updateScreenOut(current)
                        
                        guard let current else {
                            return
                        }
                            
                        events?(
                            .gestures(
                                .init(item: current.metadata, states: [
                                    .init(change: .move(.init(width: model.unionOffset.x, height: model.unionOffset.y)), state: .change)
                                ])
                            )
                        )
                    }
                    .onEnded { value in
                        guard galleryOptions.capability.contains(.dragging) else {
                            return
                        }
                        model.send(
                            .drag(translation: proxy.size.size.normalized(value.translation.size), state: .end, layoutOptions: galleryOptions)
                        )
                        
                        let current = model.currentImage
                        updateScreenOut(current)
                        
                        guard let current else {
                            return
                        }
                        
                        events?(
                            .gestures(
                                .init(item: current.metadata, states: [
                                    .init(change: .move(.init(width: model.unionOffset.x, height: model.unionOffset.y)), state: .end)
                                ])
                            )
                        )
                    }
            )
            .onChange(of: model.unionOffset) { newValue in
                let x = floor(newValue.x)
                let update = offset != x
                guard update else {
                    return
                }
                withAnimation(.smooth) {
                    offset = x
                }
            }
            .onChange(of: model.page, perform: { newValue in
                let item = model.images[newValue]
                events?(.moveToPage(item.metadata))
            })
#if os(iOS) || os(tvOS) || os(watchOS)
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification), perform: { _ in
                deviceOrientationChange.toggle()
            })
#endif
            .onChange(of: deviceOrientationChange, perform: { _ in
                offset = Double(-model.page)
                model.reset()
                if let image = model.currentImage {
                    events?(.deviceOrientationChange(image.metadata))
                }
            })
        }
        .overlayed {
            if animateProgress >= 1, galleryOptions.panelEnable {
                DefaultPanelView(model: model, onTapBack: {
                    tapBackIcon?()
                })
            }
        }
        .environment(\.events, { value in
            updateScreenOut(model.currentImage)
            events?(value)
        })
    }
    
    private func updateScreenOut(_ item: GallrayViewModel.Item?) {
        guard let item else {
            return
        }
        let next = item.unionState.factor > 1
        guard sharedState.current.isScaled != next else {
            return
        }
        sharedState.current = item.unionState
    }
}

#Preview {
    ImagesGallaryView(images: [
        URL(string: "https://images.duanlndzi.bar/ecdb7c18e93fc76d336a787b7e357de5.jpg")!,
        URL(string: "https://images.duanlndzi.bar/1f004901f2efc537f58733b2253ecb9e.jpg")!
    ], selectedImage: 0)
    .environment(\.urlImageService, URLImageService(fileStore: nil, inMemoryStore: URLImageInMemoryStore()))
}
