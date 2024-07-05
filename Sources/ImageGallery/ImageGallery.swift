import SwiftUI
import URLImageStore
import URLImage
import OSLog

public protocol ImageProvider {
    var url: URL { get }
}

extension URL: ImageProvider {
    public var url: URL {
        self
    }
}

enum UserAction {
    case tap(Int)
    case doubleTap(Int)
    case doubleTapOutside
    case drage(Int)
    case scale(Int)
    case rotate(Int)
}

fileprivate let logger = Logger(subsystem: "UI", category: "ImageGallrey")

public struct ImagesGallary: View {
    @StateObject private var model: GallrayViewModel
    @State private var offset: Double
    @State private var deviceOrientationChange = false
    
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
                }
            }
            .frame(width: proxy.size.width * CGFloat(max(model.images.count, 1)))
            .background(Color.black.ignoresSafeArea())
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture(coordinateSpace: .local)
                    .onChanged { value in
                        guard let currentImage = model.currentImage else {
                            return
                        }
                        
                        let size = proxy.size
                        
                        guard currentImage.state.bounds.width <= 1 else {
                            let translation = proxy.size.size.normalization(value.translation.size)
                            currentImage.tempState = currentImage.state.transform(.init(mode: .move(translation)))
                            model.activeDragState(currentImage)
                            model.isDrag = false
                            return
                        }
                        
                        model.endImagesDragState()
                        model.isDrag = true
                        
                        model.tempOffset = model.contentOffset.offset(CGSize(width: value.translation.width, height: 0))
                        onOffsetChange(model.tempOffset.x, in: size)
                    }
                    .onEnded { value in
                        guard let currentImage = model.currentImage else {
                            model.isDrag = false
                            return
                        }
                        
                        let size = proxy.size
                        
                        guard currentImage.state.bounds.width <= 1 else {
                            let translation = proxy.size.size.normalization(value.translation.size)
                            let (value, _) = ImageFrameBounce(state: currentImage.state, next: translation).control()
                            let nextState = currentImage.state.transform(.init(mode: .move(value)))
                            currentImage.state = nextState
                            currentImage.tempState = nextState
                            model.endImagesDragState()
                            model.isDrag = false
                            return
                        }
                        
                        model.endImagesDragState()
                        let lastOffset = model.contentOffset
                        let predictValue = lastOffset.offset(CGSize(width: value.translation.width, height: 0))
                        var next = min(max(predictValue.x, -size.width * Double(model.images.count - 1)), 0)
                        let remind = abs(next.truncatingRemainder(dividingBy: size.width))
                        next += lastOffset.x > next && remind > (size.width / 3.0) ? -(size.width - remind):remind
                        model.contentOffset = CGPoint(x: next, y: 0)
                        model.tempOffset = CGPoint(x: next, y: 0)
                        model.isDrag = false
                        onOffsetChange(next, in: size)
                    }
            )
            .onChange(of: model.unionOffset) { newValue in
                let x = newValue.x
                let update = offset != x
                guard update else {
                    return
                }
                if model.isDrag {
                    withAnimation(.spring(blendDuration: 0.1).speed(1.5)) {
                        offset = x
                    }
                    return
                }
                withAnimation(.spring().speed(1.5)) {
                    offset = x
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification), perform: { _ in
                deviceOrientationChange.toggle()
            })
            .onChange(of: deviceOrientationChange, perform: { _ in
                model.images.forEach { item in
                    item.state = .default
                    item.tempState = .default
                }
                offset = CGFloat(-model.page) * proxy.size.width
                model.contentOffset = .init(x: offset, y: 0)
            })
        }
        .overlayed {
            VStack(alignment: .center, spacing: 0) {
                HStack {
                    Spacer()
                    Text("\(model.page + 1)/\(model.images.count)")
                        .foregroundColor(.white)
                    Spacer()
                }
                .frame(height: 44)
                .overlay(Image(systemName: "arrow.left").foregroundColor(.white), alignment: .leading)
                
                Spacer()
                
                Rectangle()
                    .foregroundColor(.blue.opacity(0.8))
                    .frame(height: 56)
            }
        }
    }
    
    private func onOffsetChange(_ newValue: CGFloat, in parentSize: CGSize) {
        model.page = indexOf(newValue, in: parentSize)
    }
    
    private func indexOf(_ x: CGFloat, in parentSize: CGSize) -> Int {
        guard x < 0 else {
            return 0
        }
        
        let next = abs(
            Int(
                (x / parentSize.width).rounded(.towardZero)
            )
        )
        
        return max(min(model.images.count - 1, next), 0)
    }
}

#Preview {
    ImagesGallary(images: [
        URL(string: "https://images.duanlndzi.bar/ecdb7c18e93fc76d336a787b7e357de5.jpg")!,
        URL(string: "https://images.duanlndzi.bar/1f004901f2efc537f58733b2253ecb9e.jpg")!
    ])
    .environment(\.urlImageService, URLImageService(fileStore: nil, inMemoryStore: URLImageInMemoryStore()))
}
