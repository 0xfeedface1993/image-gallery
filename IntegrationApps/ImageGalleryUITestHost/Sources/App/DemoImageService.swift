import Dispatch
import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import URLImage
import URLImageStore

@MainActor
final class DemoImageService {
    static let shared = DemoImageService()

    let fileStore = URLImageFileStore()
    let service: URLImageService
    private var preloaded = false

    private init() {
        service = URLImageService(fileStore: fileStore, inMemoryStore: URLImageInMemoryStore())
    }

    func preload(photos: [DemoPhoto]) {
        guard !preloaded else {
            return
        }
        preloaded = true

        for photo in photos {
            guard let data = makePNG(size: photo.sourceSize, color: UIColor(photo.color)) else {
                continue
            }
            fileStore.storeImageData(data, info: URLImageStoreInfo(url: photo.url, uti: UTType.png.identifier))
            waitUntilCached(url: photo.url, timeout: 1.5)
        }
    }

    private func makePNG(size: CGSize, color: UIColor) -> Data? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData()
    }

    private func waitUntilCached(url: URL, timeout: TimeInterval) {
        let semaphore = DispatchSemaphore(value: 0)
        fileStore.getImage(url, maxPixelSize: nil, completionQueue: DispatchQueue.global(qos: .userInitiated)) { _ in
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + timeout)
    }
}
