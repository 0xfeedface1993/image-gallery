import CoreGraphics
import Testing
import ScreenOut

@Test
func targetFrame_landscapeImage_fitsBoundsWidth() {
    let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)
    let source = CGRect(x: -120, y: -45, width: 240, height: 90)

    let target = ScreenOutGeometryMath.targetFrame(for: source, in: bounds)

    #expect(isClose(target.width, 390))
    #expect(isClose(target.height, 146.25))
    #expect(isClose(target.midX, 0))
    #expect(isClose(target.midY, 0))
}

@Test
func targetFrame_portraitImage_fitsBoundsHeight() {
    let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)
    let source = CGRect(x: -50, y: -150, width: 100, height: 300)

    let target = ScreenOutGeometryMath.targetFrame(for: source, in: bounds)

    #expect(isClose(target.width, 281.3333333333))
    #expect(isClose(target.height, 844))
    #expect(isClose(target.midX, 0))
    #expect(isClose(target.midY, 0))
}

@Test
func targetFrame_portraitImage_widerThanScreenRatio_usesAspectFitAndNeverOverflowsBounds() {
    let bounds = CGRect(x: 0, y: 0, width: 440, height: 956)
    let source = CGRect(x: -48, y: -90, width: 96, height: 180)

    let target = ScreenOutGeometryMath.targetFrame(for: source, in: bounds)

    #expect(isClose(target.height, 825))
    #expect(isClose(target.width, 440))
    #expect(target.width <= bounds.width)
    #expect(target.height <= bounds.height)
    #expect(isClose(target.midX, 0))
    #expect(isClose(target.midY, 0))
}

@Test
func targetFrame_squareImage_fitsBoundsWidth() {
    let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)
    let source = CGRect(x: -60, y: -60, width: 120, height: 120)

    let target = ScreenOutGeometryMath.targetFrame(for: source, in: bounds)

    #expect(isClose(target.width, 390))
    #expect(isClose(target.height, 390))
    #expect(isClose(target.midX, 0))
    #expect(isClose(target.midY, 0))
}

@Test
func interpolatedFrame_matchesEndpointsAndMidpoint() {
    let source = CGRect(x: -70, y: -110, width: 140, height: 220)
    let target = CGRect(x: -195, y: -422, width: 390, height: 844)

    let atStart = ScreenOutGeometryMath.interpolatedFrame(from: source, to: target, progress: 0)
    let atMiddle = ScreenOutGeometryMath.interpolatedFrame(from: source, to: target, progress: 0.5)
    let atEnd = ScreenOutGeometryMath.interpolatedFrame(from: source, to: target, progress: 1)

    #expect(isClose(atStart.origin.x, source.origin.x))
    #expect(isClose(atStart.origin.y, source.origin.y))
    #expect(isClose(atStart.width, source.width))
    #expect(isClose(atStart.height, source.height))

    #expect(isClose(atMiddle.origin.x, (source.origin.x + target.origin.x) / 2))
    #expect(isClose(atMiddle.origin.y, (source.origin.y + target.origin.y) / 2))
    #expect(isClose(atMiddle.width, (source.width + target.width) / 2))
    #expect(isClose(atMiddle.height, (source.height + target.height) / 2))

    #expect(isClose(atEnd.origin.x, target.origin.x))
    #expect(isClose(atEnd.origin.y, target.origin.y))
    #expect(isClose(atEnd.width, target.width))
    #expect(isClose(atEnd.height, target.height))
}

private func isClose(_ lhs: CGFloat, _ rhs: CGFloat, tolerance: CGFloat = 0.001) -> Bool {
    abs(lhs - rhs) <= tolerance
}
