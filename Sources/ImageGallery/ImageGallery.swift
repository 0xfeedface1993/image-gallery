import SwiftUI
import URLImageStore
import URLImage

public protocol ImageProvider {
    var url: URL { get }
}

extension URL: ImageProvider {
    public var url: URL {
        self
    }
}

public struct ImagesGallary: View {
    @StateObject private var model: GallrayViewModel
    @State private var offset: Double
    
    public init(images: [ImageProvider]) {
        self.offset = .zero
        self._model = .init(wrappedValue: .init(images))
    }
    
    public var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .center, spacing: 0) {
                ForEach(model.images, id: \.url) { image in
                    ImageNodeView(item: image)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .environment(\.imageTargetTransformer,  { (base, current, next) in
                            let (value, overflow) = ImageFrameBounce(state: base, containerSize: proxy.size.size, next: next).control()
                            switch overflow {
                            case .none:
                                break
                            case .leadingOut(let space):
                                guard base.size.width == proxy.size.width else {
                                    Task { @MainActor in
                                        withAnimation(.spring().speed(1.5)) {
                                            offset = model.contentOffset.x
                                        }
                                    }
                                    break
                                }
                                let scrollOffset = model.contentOffset.offset(.init(width: -space, height: 0))
                                var nextLocation = CGPoint(x: min(max(scrollOffset.x, -proxy.size.width), 0), y: scrollOffset.y)
                                let remind = abs(nextLocation.x.truncatingRemainder(dividingBy: proxy.size.width))
                                let isNextPageEnable = model.contentOffset.x > nextLocation.x && remind > (proxy.size.width / 3.0)
                                nextLocation.x = floor(nextLocation.x + (isNextPageEnable ? -(proxy.size.width - remind):remind))
                                model.contentOffset = nextLocation
                                Task { @MainActor in
                                    withAnimation(.spring().speed(1.5)) {
                                        offset = nextLocation.x
                                    }
                                }
                                onOffsetChange(nextLocation.x, in: proxy.size)
                            case .trallingOut(let space):
                                guard base.size.width == proxy.size.width else {
                                    Task { @MainActor in
                                        withAnimation(.spring().speed(1.5)) {
                                            offset = model.contentOffset.x
                                        }
                                    }
                                    break
                                }
                                let scrollOffset = model.contentOffset.offset(.init(width: space, height: 0))
                                var nextLocation = CGPoint(x: min(max(scrollOffset.x, -proxy.size.width), 0), y: scrollOffset.y)
                                let remind = abs(nextLocation.x.truncatingRemainder(dividingBy: proxy.size.width))
                                let isNextPageEnable = model.contentOffset.x > nextLocation.x && remind > (proxy.size.width / 3.0)
                                nextLocation.x = floor(nextLocation.x + (isNextPageEnable ? -(proxy.size.width - remind):remind))
                                model.contentOffset = nextLocation
                                Task { @MainActor in
                                    withAnimation(.spring().speed(1.5)) {
                                        offset = nextLocation.x
                                    }
                                }
                                onOffsetChange(nextLocation.x, in: proxy.size)
                            }
                            return value
                        })
                        .environment(\.imageProgressTransformer, { base, next in
                            if base.size.width == proxy.size.width {
                                let (value, overflow) = ImageFrameBounce(state: base, containerSize: proxy.size.size, next: next).control()
                                switch overflow {
                                case .none:
                                    break
                                case .leadingOut(let space):
                                    guard base.size.width == proxy.size.width else {
                                        break
                                    }
                                    let scrollOffset = model.contentOffset.offset(.init(width: floor(-space), height: 0))
                                    offset = scrollOffset.x
//                                    withAnimation(.smooth) {
//                                        offset = scrollOffset.x
//                                    }
                                case .trallingOut(let space):
                                    guard base.size.width == proxy.size.width else {
                                        break
                                    }
                                    let scrollOffset = model.contentOffset.offset(.init(width: floor(space), height: 0))
                                    withAnimation(.smooth) {
                                        offset = scrollOffset.x
                                    }
                                }
                                return value
                            }
                            
                            return next
                        })
                }
            }
            .frame(width: proxy.size.width * CGFloat(max(model.images.count, 1)))
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation.width + model.contentOffset.x
                        onOffsetChange(offset, in: proxy.size)
                    }
                    .onEnded { value in
                        let oldValue = offset
                        var next = min(max(oldValue, -proxy.size.width), 0)
                        let remind = abs(next.truncatingRemainder(dividingBy: proxy.size.width))
                        next += model.contentOffset.x > next && remind > (proxy.size.width / 3.0) ? -(proxy.size.width - remind):remind
                        model.contentOffset = CGPoint(x: next, y: 0)
                        if next != oldValue {
                            withAnimation(.spring().speed(1.5)) {
                                offset = next
                            }
                        }
                        onOffsetChange(next, in: proxy.size)
                    }
            )
        }
    }
    
    private func onOffsetChange(_ newValue: CGFloat, in parentSize: CGSize) {
        model.page = indexOf(newValue, in: parentSize)
    }
    
    private func indexOf(_ x: CGFloat, in parentSize: CGSize) -> Int {
        guard x < 0 else {
            return 0
        }
        return Int(
            ceil(
                x.truncatingRemainder(dividingBy: parentSize.width)
            )
        )
    }
}

#Preview {
    ImagesGallary(images: [
        URL(string: "https://images.duanlndzi.bar/ecdb7c18e93fc76d336a787b7e357de5.jpg")!,
        URL(string: "https://images.duanlndzi.bar/1f004901f2efc537f58733b2253ecb9e.jpg")!
    ])
    .environment(\.urlImageService, URLImageService(fileStore: nil, inMemoryStore: URLImageInMemoryStore()))
}
