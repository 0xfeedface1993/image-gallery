import XCTest

final class ImageGalleryUITestHostUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testLandscapePreviewFrameIsCenteredAndWide() throws {
        verifyPreviewFrame(photoID: "landscape", expectedRatio: 180.0 / 96.0, tolerance: 0.16)
    }

    func testPortraitPreviewFrameIsCenteredAndTall() throws {
        verifyPreviewFrame(photoID: "portrait", expectedRatio: 96.0 / 180.0, tolerance: 0.10)
    }

    func testSquarePreviewFrameIsCenteredAndSquare() throws {
        verifyPreviewFrame(photoID: "square", expectedRatio: 1.0, tolerance: 0.10)
    }

    func testSwipeChangesCurrentPageRatio() throws {
        openPreview(photoID: "landscape")
        let beforePayload = waitForPayload(containing: "IG_TEST:landscape:", timeout: 10)
        let beforeMetrics = parseMetrics(from: beforePayload)

        app.swipeLeft()
        waitForStableAnimation()

        let afterPayload = waitForPayload(containing: "IG_TEST:portrait:", timeout: 10)
        let afterMetrics = parseMetrics(from: afterPayload)

        XCTAssertLessThan(afterMetrics.ratio, beforeMetrics.ratio)
        XCTAssertEqual(afterMetrics.ratio, 96.0 / 180.0, accuracy: 0.15)
    }

    private func verifyPreviewFrame(photoID: String, expectedRatio: CGFloat, tolerance: CGFloat) {
        openPreview(photoID: photoID)
        let payload = waitForPayload(containing: "IG_TEST:\(photoID):", timeout: 10)
        let metrics = parseMetrics(from: payload)

        XCTAssertEqual(metrics.ratio, expectedRatio, accuracy: tolerance)
        XCTAssertEqual(metrics.cx, metrics.W / 2, accuracy: 16)
        XCTAssertEqual(metrics.cy, metrics.H / 2, accuracy: 16)
    }

    private func openPreview(photoID: String) {
        let thumb = app.descendants(matching: .any).matching(identifier: "thumb.\(photoID)").firstMatch
        XCTAssertTrue(thumb.waitForExistence(timeout: 6))
        thumb.tap()
        _ = waitForPayload(containing: "IG_TEST:\(photoID):", timeout: 15)
    }

    private func waitForPayload(containing needle: String, timeout: TimeInterval) -> String {
        let payload = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "IG_TEST:")).firstMatch
        XCTAssertTrue(payload.waitForExistence(timeout: timeout))

        let predicate = NSPredicate(format: "label CONTAINS %@", needle)
        let exp = expectation(for: predicate, evaluatedWith: payload)
        wait(for: [exp], timeout: timeout)

        return payload.label
    }

    private func parseMetrics(from payload: String) -> (ratio: CGFloat, cx: CGFloat, cy: CGFloat, W: CGFloat, H: CGFloat) {
        var values: [String: CGFloat] = [:]

        for segment in payload.split(separator: ":") {
            let pair = segment.split(separator: "=", maxSplits: 1)
            guard pair.count == 2,
                  let value = Double(pair[1]) else {
                continue
            }
            values[String(pair[0])] = CGFloat(value)
        }

        let width = values["w"] ?? 0
        let height = values["h"] ?? 1
        let cx = values["cx"] ?? 0
        let cy = values["cy"] ?? 0
        let W = values["W"] ?? 0
        let H = values["H"] ?? 0

        return (ratio: width / max(height, 0.0001), cx: cx, cy: cy, W: W, H: H)
    }

    private func waitForStableAnimation() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
    }
}
