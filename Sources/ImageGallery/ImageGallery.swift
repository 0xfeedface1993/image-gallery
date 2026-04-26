import SwiftUI
import URLImage
import Core
import ScreenOut
import ComposableArchitecture

public struct ImageGalleryView<Overlay: View>: View {
    public var images: [ImageProvider]
    public var startSelectedImage: Int
    public var events: ((Events) -> Void)?
    public var tapBackIcon: (() -> Void)?
    private var overlayBuilder: (ImageProvider, ImageLayoutDiscription) -> Overlay

    public init(images: [ImageProvider], selectedImage: Int = 0, events: ((Events) -> Void)? = nil, tapBackIcon: (() -> Void)? = nil, @ViewBuilder overlayBuilder: @escaping (ImageProvider, ImageLayoutDiscription) -> Overlay) {
        self.images = images
        self.tapBackIcon = tapBackIcon
        self.events = events
        self.startSelectedImage = selectedImage
        self.overlayBuilder = overlayBuilder
    }

    public var body: some View {
        ImagesGallaryWrapper(images: images, selectedImage: startSelectedImage, attached: overlayBuilder, events: events, tapBackIcon: tapBackIcon)
            .id(ImageGalleryContentIdentity(urls: images.map(\.url)))
    }
}

private struct ImageGalleryContentIdentity: Hashable {
    let urls: [URL]
}

public extension ImageGalleryView where Overlay == EmptyView {
    init(images: [ImageProvider], selectedImage: Int = 0, events: ((Events) -> Void)? = nil, tapBackIcon: (() -> Void)? = nil) {
        self.init(images: images, selectedImage: selectedImage, events: events, tapBackIcon: tapBackIcon) { _, _ in
            EmptyView()
        }
    }
}

@available(*, deprecated, renamed: "ImageGalleryView")
public typealias ImagesGallaryView = ImageGalleryView<EmptyView>

public struct ImagesGallaryWrapper<Content: View>: View {
    @State private var store: StoreOf<ImageGalleryFeature>
    @State private var lastDoubleTapTime: TimeInterval = 0
    @State private var lastIsPortrait: Bool?

    @Environment(\.galleryOptions) private var galleryOptions
    @Environment(\.coverBackgroundColor) private var coverBackgroundColor
    @Environment(\.animateProgress) private var animateProgress
    @EnvironmentObject private var sharedState: GestureShareState

    private let images: [ImageProvider]
    private let attachedView: (ImageProvider, ImageLayoutDiscription) -> Content

    public var events: ((Events) -> Void)?
    public var tapBackIcon: (() -> Void)?

    public init(images: [ImageProvider], selectedImage: Int = 0, @ViewBuilder attached: @escaping (ImageProvider, ImageLayoutDiscription) -> Content, events: ((Events) -> Void)? = nil, tapBackIcon: (() -> Void)? = nil) {
        self.images = images
        self.events = events
        self.tapBackIcon = tapBackIcon
        self.attachedView = attached
        _store = State(initialValue: Store(initialState: ImageGalleryFeature.State(imageCount: images.count, selectedIndex: selectedImage), reducer: {
            ImageGalleryFeature()
        }))
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            GeometryReader { proxy in
                let containerSize = proxy.size

                ZStack(alignment: .center) {
                    pagesView(viewStore: viewStore, containerSize: containerSize)
                }
                .frame(width: containerSize.width, height: containerSize.height)
                .contentShape(Rectangle())
                .gesture(dragGesture(viewStore: viewStore), including: .gesture)
                .simultaneousGesture(magnifyGesture(viewStore: viewStore))
                .modifier(
                    GalleryTapGestureModifier(
                        animateProgress: animateProgress,
                        onSingleTap: {
                            let now = Date().timeIntervalSinceReferenceDate
                            guard now - lastDoubleTapTime > 0.25 else {
                                return
                            }
                            viewStore.send(.tap)
                            events?(.tap(currentImage(from: viewStore.state)))
                        },
                        onDoubleTap: { location in
                            lastDoubleTapTime = Date().timeIntervalSinceReferenceDate
                            viewStore.send(.doubleTap(location: location), animation: .spring(response: 0.28, dampingFraction: 0.85))
                            if let image = currentImage(from: viewStore.state) {
                                events?(.doubleTap(image))
                            }
                            updateDismissEnable(viewStore.state)
                        }
                    )
                )
                .onAppear {
                    viewStore.send(.setContainerSize(containerSize))
                    updateDismissEnable(viewStore.state)
                    emitCurrentPageEvent(viewStore.state)
                }
                .onChange(of: containerSize) { newSize in
                    viewStore.send(.setContainerSize(newSize))
                    updateDismissEnable(viewStore.state)

                    let portrait = newSize.height >= newSize.width
                    if let lastIsPortrait, lastIsPortrait != portrait, let item = currentImage(from: viewStore.state) {
                        events?(.deviceOrientationChange(item))
                    }
                    lastIsPortrait = portrait
                }
                .onChange(of: viewStore.selectedIndex) { _ in
                    emitCurrentPageEvent(viewStore.state)
                    updateDismissEnable(viewStore.state)
                }
                .onChange(of: currentPageScale(in: viewStore.state)) { _ in
                    updateDismissEnable(viewStore.state)
                }
            }
            .background {
                coverBackgroundColor.ignoresSafeArea()
            }
            .overlay(alignment: .top) {
                if animateProgress == 1, galleryOptions.panelEnable {
                    DefaultPanelView(
                        currentPage: min(max(viewStore.selectedIndex + 1, 0), max(viewStore.pages.count, 1)),
                        totalPages: max(viewStore.pages.count, 1),
                        isVisible: viewStore.isPanelVisible,
                        onTapBack: {
                            tapBackIcon?()
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func pagesView(viewStore: ViewStore<ImageGalleryFeature.State, ImageGalleryFeature.Action>, containerSize: CGSize) -> some View {
        let safeWidth = max(containerSize.width, 1)
        let safeHeight = max(containerSize.height, 1)

        ZStack(alignment: .center) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                let pageState = viewStore.pages[index]
                let pageOffsetX = CGFloat(index - viewStore.selectedIndex) * safeWidth + viewStore.pageDragOffset

                GalleryPageView(
                    image: image,
                    pageState: pageState,
                    containerSize: CGSize(width: safeWidth, height: safeHeight),
                    overlayBuilder: { layout in
                        attachedView(image, layout)
                    },
                    onImageSize: { size in
                        viewStore.send(.setImageSize(index: index, size: size))
                    },
                    onLoadingProgress: { progress in
                        viewStore.send(.setImageLoading(index: index, progress: progress))
                    },
                    onLoaded: {
                        viewStore.send(.markImageLoaded(index: index))
                    }
                )
                .frame(width: safeWidth, height: safeHeight)
                .offset(x: pageOffsetX)
                .accessibilityIdentifier("ig.page.\(index)")
            }
        }
        .frame(width: safeWidth, height: safeHeight, alignment: .center)
        .clipped()
    }

    private func dragGesture(viewStore: ViewStore<ImageGalleryFeature.State, ImageGalleryFeature.Action>) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard animateProgress == 1,
                      galleryOptions.capability.contains(.dragging) else {
                    return
                }
                viewStore.send(.dragChanged(translation: value.translation))

                if let current = currentImage(from: viewStore.state) {
                    events?(
                        .gestures(
                            .init(item: current, states: [
                                .init(change: .move(value.translation), state: .change)
                            ])
                        )
                    )
                }
            }
            .onEnded { value in
                guard animateProgress == 1,
                      galleryOptions.capability.contains(.dragging) else {
                    return
                }
                viewStore.send(
                    .dragEnded(
                        translation: value.translation,
                        predictedEndTranslation: value.predictedEndTranslation
                    ),
                    animation: .spring(response: 0.3, dampingFraction: 0.84)
                )

                if let current = currentImage(from: viewStore.state) {
                    events?(
                        .gestures(
                            .init(item: current, states: [
                                .init(change: .move(value.translation), state: .end)
                            ])
                        )
                    )
                }
            }
    }

    private func magnifyGesture(viewStore: ViewStore<ImageGalleryFeature.State, ImageGalleryFeature.Action>) -> some Gesture {
        MagnificationGesture()
            .onChanged { magnification in
                guard animateProgress == 1,
                      galleryOptions.capability.contains(.scale) else {
                    return
                }
                viewStore.send(.magnifyChanged(magnification: magnification, anchor: nil))

                if let current = currentImage(from: viewStore.state) {
                    events?(
                        .gestures(
                            .init(item: current, states: [
                                .init(change: .scale(magnification), state: .change)
                            ])
                        )
                    )
                }
            }
            .onEnded { magnification in
                guard animateProgress == 1,
                      galleryOptions.capability.contains(.scale) else {
                    return
                }
                viewStore.send(.magnifyEnded, animation: .spring(response: 0.3, dampingFraction: 0.85))

                if let current = currentImage(from: viewStore.state) {
                    events?(
                        .gestures(
                            .init(item: current, states: [
                                .init(change: .scale(magnification), state: .end)
                            ])
                        )
                    )
                }
            }
    }

    private func emitCurrentPageEvent(_ state: ImageGalleryFeature.State) {
        guard let current = currentImage(from: state) else {
            return
        }
        events?(.moveToPage(current))
    }

    private func currentImage(from state: ImageGalleryFeature.State) -> ImageProvider? {
        guard images.indices.contains(state.selectedIndex) else {
            return nil
        }
        return images[state.selectedIndex]
    }

    private func currentPageScale(in state: ImageGalleryFeature.State) -> CGFloat {
        guard state.pages.indices.contains(state.selectedIndex) else {
            return 1
        }
        return state.pages[state.selectedIndex].zoomScale
    }

    private func updateDismissEnable(_ state: ImageGalleryFeature.State) {
        let enable: Bool
        if state.pages.indices.contains(state.selectedIndex) {
            enable = state.pages[state.selectedIndex].zoomScale <= 1.001
        } else {
            enable = true
        }

        guard sharedState.isDismissEnable != enable else {
            return
        }
        sharedState.isDismissEnable = enable
    }
}

private struct GalleryTapGestureModifier: ViewModifier {
    let animateProgress: Double
    let onSingleTap: () -> Void
    let onDoubleTap: (CGPoint?) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
            content
                .simultaneousGesture(
                    SpatialTapGesture(count: 1)
                        .onEnded { _ in
                            guard animateProgress == 1 else {
                                return
                            }
                            onSingleTap()
                        }
                )
                .highPriorityGesture(
                    SpatialTapGesture(count: 2)
                        .onEnded { value in
                            guard animateProgress == 1 else {
                                return
                            }
                            onDoubleTap(value.location)
                        },
                    including: .gesture
                )
        } else {
            content
                .simultaneousGesture(
                    TapGesture(count: 1)
                        .onEnded {
                            guard animateProgress == 1 else {
                                return
                            }
                            onSingleTap()
                        }
                )
                .highPriorityGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            guard animateProgress == 1 else {
                                return
                            }
                            onDoubleTap(nil)
                        },
                    including: .gesture
                )
        }
    }
}

private struct GalleryPageView<Overlay: View>: View {
    let image: ImageProvider
    let pageState: ImageGalleryFeature.State.PageState
    let containerSize: CGSize
    let overlayBuilder: (ImageLayoutDiscription) -> Overlay
    let onImageSize: (CGSize) -> Void
    let onLoadingProgress: (CGFloat?) -> Void
    let onLoaded: () -> Void

    private var fitSize: CGSize {
        let source = resolvedSourceSize
        guard source.width > 0,
              source.height > 0,
              containerSize.width > 0,
              containerSize.height > 0 else {
            return .zero
        }
        let scale = min(containerSize.width / source.width, containerSize.height / source.height)
        return CGSize(width: source.width * scale, height: source.height * scale)
    }

    private var resolvedSourceSize: CGSize {
        if pageState.sourceSize.width > 0, pageState.sourceSize.height > 0 {
            return pageState.sourceSize
        }
        return containerSize
    }

    private var displaySize: CGSize {
        CGSize(width: fitSize.width * pageState.zoomScale, height: fitSize.height * pageState.zoomScale)
    }

    private var layoutDescription: ImageLayoutDiscription {
        let sourceSize = Size(width: resolvedSourceSize.width, height: resolvedSourceSize.height)
        let center = Point(
            x: containerSize.width / 2 + pageState.contentOffset.width,
            y: containerSize.height / 2 + pageState.contentOffset.height
        )

        let minX = center.x - displaySize.width / 2
        let minY = center.y - displaySize.height / 2
        let maxX = center.x + displaySize.width / 2
        let maxY = center.y + displaySize.height / 2

        let frame = Rects(
            topLeading: .init(x: minX, y: minY),
            bottomLeading: .init(x: minX, y: maxY),
            topTrailling: .init(x: maxX, y: minY),
            bottomTrailling: .init(x: maxX, y: maxY)
        )

        return ImageLayoutDiscription(
            center: center,
            rotationAngle: .zero,
            originSize: sourceSize,
            factor: sourceSize.fitting(Size(width: containerSize.width, height: containerSize.height)) * pageState.zoomScale,
            size: Size(width: displaySize.width, height: displaySize.height),
            bounds: Size(width: displaySize.width, height: displaySize.height),
            frame: frame
        )
    }

    var body: some View {
        ZStack {
            Color.clear

            imageContent
                .frame(width: max(fitSize.width, 1), height: max(fitSize.height, 1))
                .scaleEffect(pageState.zoomScale)
                .offset(pageState.contentOffset)
                .overlay {
                    overlayBuilder(layoutDescription)
                }
        }
        .frame(width: max(containerSize.width, 1), height: max(containerSize.height, 1))
        .clipped()
    }

    @ViewBuilder
    private var imageContent: some View {
        if image.url.absoluteString.lowercased().contains(".gif") {
            GIFImage(image.url) { } inProgress: { progress in
                LoadingProgressView(progress: progress)
                    .onAppear {
                        onLoadingProgress(progress.map(CGFloat.init))
                    }
            } failure: { _, retry in
                FailureRetryView(retry: retry)
            } content: { loaded in
                loaded
                    .modifier(FadeInOnAppear())
                    .onAppear {
                        onLoaded()
                    }
            }
        } else {
            URLImage(
                image.url,
                inProgress: { progress in
                    LoadingProgressView(progress: progress)
                        .onAppear {
                            onLoadingProgress(progress.map(CGFloat.init))
                        }
                },
                failure: { _, retry in
                    FailureRetryView(retry: retry)
                },
                content: { loaded, info in
                    loaded
                        .resizable()
                        .scaledToFit()
                        .modifier(FadeInOnAppear())
                        .onAppear {
                            onImageSize(info.size)
                            onLoaded()
                        }
                }
            )
        }
    }
}

private struct LoadingProgressView: View {
    let progress: Float?

    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
            if let progress {
                ProgressView(value: Double(progress), total: 1)
                    .progressViewStyle(.linear)
                    .frame(width: 120)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct FailureRetryView: View {
    let retry: () -> Void

    var body: some View {
        Button(action: retry) {
            VStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                Text("Retry")
                    .font(.caption)
            }
            .padding(12)
            .foregroundStyle(.white)
            .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

private struct FadeInOnAppear: ViewModifier {
    @State private var opacity = 0.0

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                if opacity < 1 {
                    withAnimation(.easeOut(duration: 0.18)) {
                        opacity = 1
                    }
                }
            }
    }
}
