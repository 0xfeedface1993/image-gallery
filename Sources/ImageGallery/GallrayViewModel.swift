//
//  File.swift
//  
//
//  Created by sonoma on 6/30/24.
//

import Foundation
import ChainBuilder

final class GallrayViewModel: ObservableObject {
    /// 当前页数
    @Published var page: Int
    /// 水平卷轴偏移量
    @Published var contentOffset: CGPoint
    /// 图片列表
    @Published var images: [Item]
    
    init(_ data: [ImageProvider]) {
        self.page = 0
        self.contentOffset = .zero
        self.images = data.map(Item.init(metadata:))
    }
}

extension GallrayViewModel {
    @ChainBuiler
    final class Item: ObservableObject {
        @Published var state: ImageLayoutState
        let metadata: ImageProvider
        /// 图片地址
        let url: URL
        
        convenience init(url: URL) {
            self.init(state: ImageLayoutState(center: .zero, rotationAngle: .zero, originSize: .zero, factor: 1.0), metadata: url, url: url)
        }
        
        convenience init(metadata: ImageProvider) {
            self.init(state: ImageLayoutState(center: .zero, rotationAngle: .zero, originSize: .zero, factor: 1.0), metadata: metadata, url: metadata.url)
        }
    }
}
