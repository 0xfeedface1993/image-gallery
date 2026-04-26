import CoreGraphics
import Foundation
import ComposableArchitecture

struct ImageGalleryFeature: Reducer {
    struct State: Equatable {
        struct PageState: Equatable {
            var zoomScale: CGFloat = 1
            var contentOffset: CGSize = .zero
            var sourceSize: CGSize = .zero
            var loadingProgress: CGFloat?
            var isLoaded = false
        }

        var pages: [PageState]
        var selectedIndex: Int
        var pageDragOffset: CGFloat = 0
        var containerSize: CGSize = .zero
        var isPanelVisible = false
        var dragSession: DragSession?
        var pinchSession: PinchSession?
        var minZoomScale: CGFloat = 1
        var maxZoomScale: CGFloat = 4
        var pageTurnThresholdRatio: CGFloat = 0.23

        init(imageCount: Int, selectedIndex: Int) {
            let count = max(imageCount, 0)
            pages = Array(repeating: PageState(), count: count)
            if count == 0 {
                self.selectedIndex = 0
            } else {
                self.selectedIndex = max(0, min(count - 1, selectedIndex))
            }
        }

        var hasImages: Bool {
            !pages.isEmpty
        }

        var lastIndex: Int {
            max(0, pages.count - 1)
        }
    }

    struct DragSession: Equatable {
        enum Mode: Equatable {
            case paging(basePageOffset: CGFloat)
            case zooming(baseContentOffset: CGSize, basePageOffset: CGFloat)
        }

        var mode: Mode
    }

    struct PinchSession: Equatable {
        var baseScale: CGFloat
        var baseOffset: CGSize
        var anchor: CGPoint
    }

    enum Action: Equatable {
        case setContainerSize(CGSize)
        case setImageSize(index: Int, size: CGSize)
        case setImageLoading(index: Int, progress: CGFloat?)
        case markImageLoaded(index: Int)

        case tap
        case doubleTap(location: CGPoint?)

        case dragChanged(translation: CGSize)
        case dragEnded(translation: CGSize, predictedEndTranslation: CGSize)

        case magnifyChanged(magnification: CGFloat, anchor: CGPoint?)
        case magnifyEnded
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .setContainerSize(let size):
                guard size.width > 0, size.height > 0 else {
                    return .none
                }
                guard state.containerSize != size else {
                    return .none
                }
                state.containerSize = size
                clampAllPagesToCurrentBounds(&state)
                return .none

            case .setImageSize(let index, let size):
                guard state.pages.indices.contains(index),
                      size.width > 0,
                      size.height > 0 else {
                    return .none
                }
                state.pages[index].sourceSize = size
                state.pages[index].contentOffset = clampedOffset(
                    state.pages[index].contentOffset,
                    in: state,
                    at: index,
                    zoomScale: state.pages[index].zoomScale
                )
                return .none

            case .setImageLoading(let index, let progress):
                guard state.pages.indices.contains(index) else {
                    return .none
                }
                state.pages[index].loadingProgress = progress
                return .none

            case .markImageLoaded(let index):
                guard state.pages.indices.contains(index) else {
                    return .none
                }
                state.pages[index].isLoaded = true
                state.pages[index].loadingProgress = nil
                return .none

            case .tap:
                state.isPanelVisible.toggle()
                return .none

            case .doubleTap(let location):
                guard state.hasImages else {
                    return .none
                }

                let index = state.selectedIndex
                let page = state.pages[index]
                if page.zoomScale > 1.01 {
                    state.pages[index].zoomScale = 1
                    state.pages[index].contentOffset = .zero
                } else {
                    let anchor = location ?? CGPoint(x: state.containerSize.width / 2, y: state.containerSize.height / 2)
                    let targetScale = min(max(2, state.minZoomScale), state.maxZoomScale)
                    let targetOffset = clampedOffset(
                        transformedOffset(
                            baseOffset: page.contentOffset,
                            fromScale: page.zoomScale,
                            toScale: targetScale,
                            anchor: anchor,
                            in: state.containerSize
                        ),
                        in: state,
                        at: index,
                        zoomScale: targetScale
                    )
                    state.pages[index].zoomScale = targetScale
                    state.pages[index].contentOffset = targetOffset
                }
                return .none

            case .magnifyChanged(let magnification, let anchor):
                guard state.hasImages else {
                    return .none
                }

                let index = state.selectedIndex
                let resolvedAnchor = anchor ?? CGPoint(x: state.containerSize.width / 2, y: state.containerSize.height / 2)
                if state.pinchSession == nil {
                    state.pinchSession = PinchSession(
                        baseScale: state.pages[index].zoomScale,
                        baseOffset: state.pages[index].contentOffset,
                        anchor: resolvedAnchor
                    )
                }

                guard let pinchSession = state.pinchSession else {
                    return .none
                }

                let targetScale = min(
                    max(pinchSession.baseScale * magnification, state.minZoomScale),
                    state.maxZoomScale
                )
                let targetOffset = clampedOffset(
                    transformedOffset(
                        baseOffset: pinchSession.baseOffset,
                        fromScale: pinchSession.baseScale,
                        toScale: targetScale,
                        anchor: pinchSession.anchor,
                        in: state.containerSize
                    ),
                    in: state,
                    at: index,
                    zoomScale: targetScale
                )

                state.pages[index].zoomScale = targetScale
                state.pages[index].contentOffset = targetOffset
                return .none

            case .magnifyEnded:
                guard state.hasImages else {
                    return .none
                }
                state.pinchSession = nil
                let index = state.selectedIndex
                if state.pages[index].zoomScale <= 1.001 {
                    state.pages[index].zoomScale = 1
                    state.pages[index].contentOffset = .zero
                } else {
                    state.pages[index].contentOffset = clampedOffset(
                        state.pages[index].contentOffset,
                        in: state,
                        at: index,
                        zoomScale: state.pages[index].zoomScale
                    )
                }
                return .none

            case .dragChanged(let translation):
                guard state.hasImages else {
                    return .none
                }

                if state.dragSession == nil {
                    let current = state.pages[state.selectedIndex]
                    if current.zoomScale > 1.001 {
                        state.dragSession = DragSession(
                            mode: .zooming(
                                baseContentOffset: current.contentOffset,
                                basePageOffset: state.pageDragOffset
                            )
                        )
                    } else {
                        state.dragSession = DragSession(mode: .paging(basePageOffset: state.pageDragOffset))
                    }
                }

                guard let session = state.dragSession else {
                    return .none
                }

                switch session.mode {
                case .paging(let basePageOffset):
                    var offset = basePageOffset + translation.width
                    if isOutwardEdgeDrag(pageOffset: offset, state: state) {
                        offset *= 0.35
                    }
                    state.pageDragOffset = offset

                case .zooming(let baseContentOffset, let basePageOffset):
                    let index = state.selectedIndex
                    let limits = maximumContentOffset(in: state, at: index, zoomScale: state.pages[index].zoomScale)

                    let proposedX = baseContentOffset.width + translation.width
                    let proposedY = baseContentOffset.height + translation.height

                    var resolvedX = proposedX
                    var overflowX: CGFloat = 0

                    if limits.width > 0 {
                        if proposedX > limits.width {
                            resolvedX = limits.width
                            overflowX = proposedX - limits.width
                        } else if proposedX < -limits.width {
                            resolvedX = -limits.width
                            overflowX = proposedX + limits.width
                        }
                    } else {
                        resolvedX = 0
                        overflowX = proposedX
                    }

                    let resolvedY = rubberBand(proposedY, limit: limits.height, damping: 0.28)
                    var pageOffset = basePageOffset + overflowX
                    if isOutwardEdgeDrag(pageOffset: pageOffset, state: state) {
                        pageOffset *= 0.35
                    }

                    state.pages[index].contentOffset = CGSize(width: resolvedX, height: resolvedY)
                    state.pageDragOffset = pageOffset
                }
                return .none

            case .dragEnded(let translation, let predictedEndTranslation):
                guard state.hasImages else {
                    return .none
                }

                let threshold = max(44, state.containerSize.width * state.pageTurnThresholdRatio)
                let projectedPageOffset: CGFloat
                if let session = state.dragSession {
                    switch session.mode {
                    case .paging(let basePageOffset):
                        projectedPageOffset = basePageOffset + predictedEndTranslation.width
                    case .zooming:
                        let velocityExtra = (predictedEndTranslation.width - translation.width) * 0.35
                        projectedPageOffset = state.pageDragOffset + velocityExtra
                        let index = state.selectedIndex
                        state.pages[index].contentOffset = clampedOffset(
                            state.pages[index].contentOffset,
                            in: state,
                            at: index,
                            zoomScale: state.pages[index].zoomScale
                        )
                    }
                } else {
                    projectedPageOffset = predictedEndTranslation.width
                }

                let delta = pageDelta(for: projectedPageOffset, threshold: threshold, state: state)
                if delta != 0 {
                    state.selectedIndex = max(0, min(state.lastIndex, state.selectedIndex + delta))
                    for index in state.pages.indices where index != state.selectedIndex {
                        state.pages[index].zoomScale = 1
                        state.pages[index].contentOffset = .zero
                    }
                }

                state.pageDragOffset = 0
                state.dragSession = nil
                state.pinchSession = nil
                return .none
            }
        }
    }
}

private func clampAllPagesToCurrentBounds(_ state: inout ImageGalleryFeature.State) {
    for index in state.pages.indices {
        if state.pages[index].zoomScale <= 1.001 {
            state.pages[index].zoomScale = 1
            state.pages[index].contentOffset = .zero
            continue
        }
        state.pages[index].contentOffset = clampedOffset(
            state.pages[index].contentOffset,
            in: state,
            at: index,
            zoomScale: state.pages[index].zoomScale
        )
    }
}

private func fittedSize(in state: ImageGalleryFeature.State, at index: Int) -> CGSize {
    guard state.pages.indices.contains(index),
          state.containerSize.width > 0,
          state.containerSize.height > 0 else {
        return .zero
    }

    let source = state.pages[index].sourceSize.width > 0 && state.pages[index].sourceSize.height > 0
        ? state.pages[index].sourceSize
        : state.containerSize

    let scale = min(
        state.containerSize.width / max(source.width, 1),
        state.containerSize.height / max(source.height, 1)
    )
    return CGSize(width: source.width * scale, height: source.height * scale)
}

private func maximumContentOffset(
    in state: ImageGalleryFeature.State,
    at index: Int,
    zoomScale: CGFloat
) -> CGSize {
    let fitSize = fittedSize(in: state, at: index)
    guard fitSize.width > 0, fitSize.height > 0 else {
        return .zero
    }

    let contentWidth = fitSize.width * zoomScale
    let contentHeight = fitSize.height * zoomScale

    let maxX = max(0, (contentWidth - state.containerSize.width) / 2)
    let maxY = max(0, (contentHeight - state.containerSize.height) / 2)
    return CGSize(width: maxX, height: maxY)
}

private func clampedOffset(
    _ offset: CGSize,
    in state: ImageGalleryFeature.State,
    at index: Int,
    zoomScale: CGFloat
) -> CGSize {
    let limit = maximumContentOffset(in: state, at: index, zoomScale: zoomScale)
    return CGSize(
        width: max(-limit.width, min(limit.width, offset.width)),
        height: max(-limit.height, min(limit.height, offset.height))
    )
}

private func transformedOffset(
    baseOffset: CGSize,
    fromScale: CGFloat,
    toScale: CGFloat,
    anchor: CGPoint,
    in containerSize: CGSize
) -> CGSize {
    guard fromScale > 0 else {
        return baseOffset
    }
    let ratio = toScale / fromScale
    let deltaX = anchor.x - containerSize.width / 2
    let deltaY = anchor.y - containerSize.height / 2

    return CGSize(
        width: (baseOffset.width - deltaX) * ratio + deltaX,
        height: (baseOffset.height - deltaY) * ratio + deltaY
    )
}

private func rubberBand(_ value: CGFloat, limit: CGFloat, damping: CGFloat) -> CGFloat {
    guard limit > 0 else {
        return value * damping
    }
    if value > limit {
        return limit + (value - limit) * damping
    }
    if value < -limit {
        return -limit + (value + limit) * damping
    }
    return value
}

private func pageDelta(
    for projectedPageOffset: CGFloat,
    threshold: CGFloat,
    state: ImageGalleryFeature.State
) -> Int {
    if projectedPageOffset <= -threshold, state.selectedIndex < state.lastIndex {
        return 1
    }
    if projectedPageOffset >= threshold, state.selectedIndex > 0 {
        return -1
    }
    return 0
}

private func isOutwardEdgeDrag(pageOffset: CGFloat, state: ImageGalleryFeature.State) -> Bool {
    if pageOffset > 0, state.selectedIndex == 0 {
        return true
    }
    if pageOffset < 0, state.selectedIndex == state.lastIndex {
        return true
    }
    return false
}
