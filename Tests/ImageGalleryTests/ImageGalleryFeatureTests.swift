import CoreGraphics
import Testing
@testable import ImageGallery

@Test
func pageTurn_usesThresholdAndSettlesOnEnd() {
    var state = ImageGalleryFeature.State(imageCount: 3, selectedIndex: 1)
    let reducer = ImageGalleryFeature()

    _ = reducer.reduce(into: &state, action: .setContainerSize(CGSize(width: 300, height: 600)))

    _ = reducer.reduce(into: &state, action: .dragChanged(translation: CGSize(width: -40, height: 0)))
    _ = reducer.reduce(
        into: &state,
        action: .dragEnded(
            translation: CGSize(width: -40, height: 0),
            predictedEndTranslation: CGSize(width: -40, height: 0)
        )
    )
    #expect(state.selectedIndex == 1)

    _ = reducer.reduce(into: &state, action: .dragChanged(translation: CGSize(width: -120, height: 0)))
    _ = reducer.reduce(
        into: &state,
        action: .dragEnded(
            translation: CGSize(width: -120, height: 0),
            predictedEndTranslation: CGSize(width: -120, height: 0)
        )
    )
    #expect(state.selectedIndex == 2)
}

@Test
func doubleTap_togglesBetweenAspectFitAnd2xZoom() {
    var state = ImageGalleryFeature.State(imageCount: 1, selectedIndex: 0)
    let reducer = ImageGalleryFeature()

    _ = reducer.reduce(into: &state, action: .setContainerSize(CGSize(width: 300, height: 600)))
    _ = reducer.reduce(into: &state, action: .setImageSize(index: 0, size: CGSize(width: 200, height: 400)))

    _ = reducer.reduce(into: &state, action: .doubleTap(location: CGPoint(x: 150, y: 300)))
    #expect(abs(state.pages[0].zoomScale - 2) < 0.001)

    _ = reducer.reduce(into: &state, action: .doubleTap(location: CGPoint(x: 150, y: 300)))
    #expect(abs(state.pages[0].zoomScale - 1) < 0.001)
    #expect(state.pages[0].contentOffset == .zero)
}

@Test
func zoomedDrag_handsOffToPagingAtHorizontalEdge() {
    var state = ImageGalleryFeature.State(imageCount: 3, selectedIndex: 0)
    let reducer = ImageGalleryFeature()

    _ = reducer.reduce(into: &state, action: .setContainerSize(CGSize(width: 300, height: 600)))
    _ = reducer.reduce(into: &state, action: .setImageSize(index: 0, size: CGSize(width: 300, height: 300)))

    _ = reducer.reduce(into: &state, action: .doubleTap(location: CGPoint(x: 150, y: 300)))
    #expect(state.pages[0].zoomScale > 1)

    _ = reducer.reduce(into: &state, action: .dragChanged(translation: CGSize(width: -220, height: 0)))
    #expect(state.pages[0].contentOffset.width <= -149)
    #expect(state.pageDragOffset < 0)

    _ = reducer.reduce(
        into: &state,
        action: .dragEnded(
            translation: CGSize(width: -220, height: 0),
            predictedEndTranslation: CGSize(width: -220, height: 0)
        )
    )
    #expect(state.selectedIndex == 1)
    #expect(abs(state.pageDragOffset) < 0.001)
}
