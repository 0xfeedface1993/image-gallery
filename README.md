# ImageGallery

# Features

- [x] Browser imags like normal gallery
- [x] Support Scale & rotate, 
- [x] Support limit scale level & rotate action, just setup enviroment value gallery options
- [x] Custom your navigation bar or toolbar, or complete custom overlay view
- [x] Scale、tap、rotate gesture on & off switch on the house
- [x] GIF image supported
- [x] Drag postion center control
- [] Dismiss when drag up & with interective animation
- [] Show animation at frist time display

# Quick Start

```swift
import SwiftUI
import ImageGallery

struct Photo: Identifiable, ImageProvider {
    let id: UUID
    let url: URL
}

struct GalleryHost: View {
    @State private var activeID: UUID?
    let photos: [Photo]

    var body: some View {
        LazyVGrid(columns: [.init(.adaptive(minimum: 88))]) {
            ForEach(photos) { item in
                AsyncImage(url: item.url)
                    .frame(width: 88, height: 88)
                    .clipped()
                    .imageGallerySource(id: item.id)
                    .onTapGesture {
                        activeID = item.id
                    }
            }
        }
        .imageGalleryPreview(activeID: $activeID, items: photos, id: \.id)
    }
}
```

`imageGalleryPreview` supports an optional `overlayBuilder`:

```swift
.imageGalleryPreview(activeID: $activeID, items: photos, id: \.id) { item, layout in
    Text(item.url.lastPathComponent)
}
```

Use `ImageGalleryView` directly when you want a full-screen gallery without a source view:

```swift
ImageGalleryView(images: photos, selectedImage: 0)
```
