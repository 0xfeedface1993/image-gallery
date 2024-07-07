//
//  SwiftUIView.swift
//  
//
//  Created by sonoma on 6/30/24.
//

import SwiftUI
import URLImageStore
import AsyncSystem

struct ImageNodeView<Content: View>: View {
    @ObservedObject var item: GallrayViewModel.Item
    
    @State private var cgImage: CGImage?
    @Environment(\.urlImageService) private var service
    @State private var isLoading: Bool = false
    
    private var attachView: (GallrayViewModel.Item, ImageLayoutDiscription) -> Content
    
    init(item: GallrayViewModel.Item, @ViewBuilder attachView: @escaping (GallrayViewModel.Item, ImageLayoutDiscription) -> Content) {
        self.item = item
        self.attachView = attachView
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.clear
                
                if isLoading {
                    ProgressView()
                }
            }
            .overlayed {
                if let cgImage = cgImage {
                    ZoomingView(image: cgImage, model: item, attachView: attachView)
                        .onChange(of: item.layoutUpdate) { newValue in
                            item.imageSize = cgImage.size.normalized(in: proxy.size.size)
                        }
                }
            }
            .once {
                isLoading = true
                try? await loadImage(proxy.size.size)
                isLoading = false
            }
        }
    }
    
    private func loadImage(_ size: Size) async throws {
        guard let store = service.inMemoryStore else {
            print("inMemoryStore is nil")
            return
        }
        
        let url = item.url
        
        guard let image = store.getImage(url) else {
            print("image [\(url)] cache is invalid")
            print("downloading [\(url)] ...")
            let result = try await service.remoteImagePublisher(url, identifier: nil).asyncValue
            print("got image size \(result.size)")
            let ratio = result.cgImage.size.normalized(in: size)
            item.imageSize = ratio
            print("image size ratio: \(item.imageSize)")
            cgImage = result.cgImage
            return
        }
        
        let ratio = image.size.normalized(in: size)
        item.imageSize = ratio
        print("image size ratio: \(item.imageSize)")
        cgImage = image
    }
}

#Preview {
    ImageNodeView(item: GallrayViewModel.Item(url: URL(string: "https://images.duanlndzi.bar/ecdb7c18e93fc76d336a787b7e357de5.jpg")!), attachView: { _, _ in
        
    })
}
