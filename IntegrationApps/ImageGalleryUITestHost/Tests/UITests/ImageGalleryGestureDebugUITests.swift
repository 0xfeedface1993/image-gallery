import XCTest

final class ImageGalleryGestureDebugUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ig-debug-logs"]
        app.launch()
    }

    func testCaptureGestureLogsFromPortraitPage() throws {
        let thumb = app.descendants(matching: .any).matching(identifier: "thumb.portrait").firstMatch
        XCTAssertTrue(thumb.waitForExistence(timeout: 8))
        thumb.tap()
        wait(seconds: 1.0)

        // Partial drag then release to capture transition-end behavior.
        drag(from: CGVector(dx: 0.75, dy: 0.50), to: CGVector(dx: 0.40, dy: 0.50))
        wait(seconds: 1.2)

        // Full page swipe to capture settled page positions around index 2.
        drag(from: CGVector(dx: 0.75, dy: 0.50), to: CGVector(dx: 0.08, dy: 0.50))
        wait(seconds: 1.2)
    }

    private func drag(from start: CGVector, to end: CGVector) {
        let startCoordinate = app.coordinate(withNormalizedOffset: start)
        let endCoordinate = app.coordinate(withNormalizedOffset: end)
        startCoordinate.press(forDuration: 0.03, thenDragTo: endCoordinate)
    }

    private func wait(seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }
}
