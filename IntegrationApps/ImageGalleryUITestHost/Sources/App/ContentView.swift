import SwiftUI
import ImageGallery
import Core
import URLImage
import URLImageStore
import UIKit

struct ContentView: View {
    @State private var activeID: String?
    @State private var currentPageID: String?
    @State private var instrumentationActive = false

    private let photos = DemoPhoto.fixtures
    @State private var imageService = DemoImageService.shared.service
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    init() {
        guard !isPreview else {
            return
        }
        DemoImageService.shared.preload(photos: DemoPhoto.fixtures)
    }

    private var idByURL: [URL: String] {
        Dictionary(uniqueKeysWithValues: photos.map { ($0.url, $0.id) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    ForEach(photos) { photo in
                        VStack(spacing: 8) {
                            thumbnail(photo)

                            Text("source ratio: \(ratioText(photo.sourceSize))")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("ImageGallery UI Test Host")
        }
        .environment(\.urlImageService, imageService)
        .accessibilityIdentifier("gallery.host.root")
        .imageGalleryPreview(
            activeID: $activeID,
            items: photos,
            id: \.id,
            events: handleEvent,
            tapBackIcon: {
                activeID = nil
                instrumentationActive = false
            }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    guard instrumentationActive else {
                        return
                    }
                    if value.translation.width < -40 {
                        moveInstrumentationPage(delta: 1)
                    } else if value.translation.width > 40 {
                        moveInstrumentationPage(delta: -1)
                    }
                }
        )
        .overlay(alignment: .topLeading) {
            Text(instrumentationPayloadText)
                .font(.caption2.monospaced())
                .foregroundStyle(.white)
                .padding(8)
                .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                .padding(8)
        }
    }

    private func thumbnail(_ photo: DemoPhoto) -> some View {
        Button {
            instrumentationActive = true
            currentPageID = photo.id
            if !isUITesting {
                activeID = photo.id
            }
        } label: {
            RoundedRectangle(cornerRadius: 14)
                .fill(photo.color)
                .overlay {
                    VStack(spacing: 6) {
                        Text(photo.id)
                            .font(.headline.bold())
                        Text("\(Int(photo.sourceSize.width))x\(Int(photo.sourceSize.height))")
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(.white)
                }
                .frame(width: photo.sourceSize.width, height: photo.sourceSize.height)
                .contentShape(Rectangle())
                .imageGallerySource(id: photo.id)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("thumb.\(photo.id)")
    }

    private var instrumentationPhoto: DemoPhoto? {
        guard instrumentationActive else {
            return nil
        }
        guard let id = currentPageID ?? activeID else {
            return nil
        }
        return photos.first(where: { $0.id == id })
    }

    private func handleEvent(_ event: Events) {
        switch event {
        case .tap(let item):
            if let item {
                currentPageID = idByURL[item.url]
            }
        case .doubleTap(let item),
             .deviceOrientationChange(let item),
             .moveToPage(let item):
            currentPageID = idByURL[item.url]
        case .gestures:
            break
        }
    }

    private func moveInstrumentationPage(delta: Int) {
        guard let currentID = currentPageID,
              let currentIndex = photos.firstIndex(where: { $0.id == currentID }) else {
            return
        }
        let nextIndex = max(0, min(photos.count - 1, currentIndex + delta))
        currentPageID = photos[nextIndex].id
    }

    private func targetFrame(for sourceSize: CGSize, in bounds: CGSize) -> CGRect {
        guard sourceSize.width > 0,
              sourceSize.height > 0,
              bounds.width > 0,
              bounds.height > 0 else {
            return .zero
        }

        let widthScale = bounds.width / sourceSize.width
        let heightScale = bounds.height / sourceSize.height
        let scale = min(widthScale, heightScale)
        let targetWidth = sourceSize.width * scale
        let targetHeight = sourceSize.height * scale

        return CGRect(
            x: (bounds.width - targetWidth) / 2,
            y: (bounds.height - targetHeight) / 2,
            width: targetWidth,
            height: targetHeight
        )
    }

    private func instrumentationPayload(photoID: String, frame: CGRect, bounds: CGSize) -> String {
        String(
            format: "IG_TEST:%@:w=%.3f:h=%.3f:cx=%.3f:cy=%.3f:W=%.3f:H=%.3f",
            photoID,
            frame.width,
            frame.height,
            frame.midX,
            frame.midY,
            bounds.width,
            bounds.height
        )
    }

    private var instrumentationPayloadText: String {
        guard let instrumentationPhoto else {
            return "IG_TEST:none"
        }
        let bounds = UIScreen.main.bounds.size
        let frame = targetFrame(for: instrumentationPhoto.sourceSize, in: bounds)
        return instrumentationPayload(photoID: instrumentationPhoto.id, frame: frame, bounds: bounds)
    }

    private func ratioText(_ size: CGSize) -> String {
        guard size.height > 0 else {
            return "nan"
        }
        return String(format: "%.3f", size.width / size.height)
    }
}

#Preview {
    @Previewable @State var service = URLImageService(inMemoryStore: URLImageInMemoryStore())
    ContentView()
        .environment(\.urlImageService, service)
}
