//
//  SwiftUIView.swift
//  
//
//  Created by sonoma on 6/30/24.
//

import SwiftUI
import URLImageStore
import AnyErase

struct ImageNodeView: View {
    @ObservedObject var item: GallrayViewModel.Item
    
    @State private var cgImage: CGImage?
    @Environment(\.urlImageService) private var service
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            Color.clear
            
            if isLoading {
                ProgressView()
            }
        }
        .overlayed {
            if let cgImage = cgImage {
                ZoomingView(image: cgImage, model: item)
            }
        }
        .once {
            isLoading = true
            try? await loadImage()
            isLoading = false
        }
    }
    
    private func loadImage() async throws {
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
            cgImage = result.cgImage
            return
        }
        
        cgImage = image
    }
}

#Preview {
    ImageNodeView(item: GallrayViewModel.Item(url: URL(string: "https://images.duanlndzi.bar/ecdb7c18e93fc76d336a787b7e357de5.jpg")!))
}
