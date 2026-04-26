import Testing
@testable import ImageGallery
import SwiftUI
import Core

@Test
@MainActor
func api_smoke_compilesNewModifiers() {
    struct Fixture: ImageProvider {
        let id: Int
        let url: URL
    }

    let items = [Fixture(id: 1, url: URL(string: "https://example.com/1.jpg")!)]
    let binding = Binding<Int?>(
        get: { nil },
        set: { _ in }
    )

    _ = Color.clear.imageGallerySource(id: items[0].id)
    _ = VStack {}.imageGalleryPreview(activeID: binding, items: items, id: \.id)
}

@Test
func fitting_portraitThatIsRelativelyWide_usesWidthScaleToKeepWholeImageVisible() {
    let imageSize = Size(width: 96, height: 180)
    let windowSize = Size(width: 440, height: 956)

    let factor = imageSize.fitting(windowSize)

    #expect(abs(factor - (440.0 / 96.0)) < 0.001)
}

@Test
func fitting_portraitThatIsRelativelyNarrow_usesHeightScale() {
    let imageSize = Size(width: 96, height: 300)
    let windowSize = Size(width: 440, height: 956)

    let factor = imageSize.fitting(windowSize)

    #expect(abs(factor - (956.0 / 300.0)) < 0.001)
}

@Test
func fitting_landscape_usesWidthScale() {
    let imageSize = Size(width: 180, height: 96)
    let windowSize = Size(width: 440, height: 956)

    let factor = imageSize.fitting(windowSize)

    #expect(abs(factor - (440.0 / 180.0)) < 0.001)
}
