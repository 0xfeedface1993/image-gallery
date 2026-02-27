import SwiftUI
import Core
import ScreenOut

private struct ImageGalleryPreviewModifier<Items: RandomAccessCollection, ID: Hashable, Overlay: View>: ViewModifier where Items.Element: ImageProvider {
    @Binding var activeID: ID?
    let items: Items
    let id: KeyPath<Items.Element, ID>
    let events: ((Events) -> Void)?
    let tapBackIcon: (() -> Void)?
    let overlayBuilder: (ImageProvider, ImageLayoutDiscription) -> Overlay

    func body(content: Content) -> some View {
        let snapshots = Array(items)

        return content
            .screenOutGeometry(activeID: $activeID) { currentID in
                if let selectedIndex = snapshots.firstIndex(where: { $0[keyPath: id] == currentID }) {
                    ImageGalleryView(images: snapshots, selectedImage: selectedIndex, events: events, tapBackIcon: tapBackIcon, overlayBuilder: overlayBuilder)
                } else {
                    Color.clear
                }
            }
    }
}

public extension View {
    @ViewBuilder
    func imageGallerySource<T: Hashable>(id: T) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: ImageFrameKey.self, value: [AnyHashable(id): proxy.frame(in: .global)])
            }
        }
    }

    @ViewBuilder
    func imageGalleryPreview<Items: RandomAccessCollection, ID: Hashable>(
        activeID: Binding<ID?>,
        items: Items,
        id: KeyPath<Items.Element, ID>,
        events: ((Events) -> Void)? = nil,
        tapBackIcon: (() -> Void)? = nil
    ) -> some View where Items.Element: ImageProvider {
        modifier(
            ImageGalleryPreviewModifier(
                activeID: activeID,
                items: items,
                id: id,
                events: events,
                tapBackIcon: tapBackIcon,
                overlayBuilder: { _, _ in
                    EmptyView()
                }
            )
        )
    }

    @ViewBuilder
    func imageGalleryPreview<Items: RandomAccessCollection, ID: Hashable, Overlay: View>(
        activeID: Binding<ID?>,
        items: Items,
        id: KeyPath<Items.Element, ID>,
        events: ((Events) -> Void)? = nil,
        tapBackIcon: (() -> Void)? = nil,
        @ViewBuilder overlayBuilder: @escaping (ImageProvider, ImageLayoutDiscription) -> Overlay
    ) -> some View where Items.Element: ImageProvider {
        modifier(
            ImageGalleryPreviewModifier(
                activeID: activeID,
                items: items,
                id: id,
                events: events,
                tapBackIcon: tapBackIcon,
                overlayBuilder: overlayBuilder
            )
        )
    }
}
