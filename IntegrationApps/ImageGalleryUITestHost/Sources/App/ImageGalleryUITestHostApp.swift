import SwiftUI
import URLImage

@main
struct ImageGalleryUITestHostApp: App {
    private let imageService = DemoImageService.shared.service

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.urlImageService, imageService)
        }
    }
}
