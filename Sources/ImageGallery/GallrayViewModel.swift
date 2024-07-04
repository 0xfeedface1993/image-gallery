//
//  File.swift
//  
//
//  Created by sonoma on 6/30/24.
//

import Foundation
import ChainBuilder
import Combine

final class GallrayViewModel: ObservableObject {
    /// 当前页数
    @Published var page: Int
    /// 水平卷轴偏移量
    @Published var contentOffset: CGPoint
    /// 水平卷轴偏移量（在手势过程中有效）
    @Published var tempOffset: CGPoint
    @Published var isDrag: Bool
    /// 图片列表
    @Published var images: [Item]
    /// UI上需要显示的水平卷轴偏移量
    @Published var unionOffset: CGPoint
    
    private var cancellation: AnyCancellable?
    
    init(_ data: [ImageProvider]) {
        self.page = 0
        self.contentOffset = .zero
        self.images = data.map(Item.init(metadata:))
        self.isDrag = false
        self.tempOffset = .zero
        self.unionOffset = .zero
        
        self.cancellation = self._isDrag.projectedValue
            .combineLatest(self._contentOffset.projectedValue, self._tempOffset.projectedValue)
            .map { dragging, base, temp in
                dragging ? temp:base
            }
            .assign(to: \.unionOffset, on: self)
    }
    
    deinit {
        self.cancellation?.cancel()
    }
    
    var currentImage: Item? {
        guard images.endIndex > page, images.startIndex <= page else {
            return nil
        }
        return images[page]
    }
    
    func endImagesDragState() {
        images.filter(\.isDrag).forEach {
            $0.isDrag = false
        }
    }
    
    func activeDragState(_ item: Item) {
        images.forEach {
            $0.isDrag = item.metadata.url == $0.metadata.url
        }
    }
}

extension GallrayViewModel {
    @ChainBuiler
    final class Item: ObservableObject {
        @Published var state: NormalizationLayoutState
        @Published var tempState: NormalizationLayoutState
        @Published var unionState: NormalizationLayoutState
        @Published var isDrag: Bool
        @Published var isRotate: Bool
        @Published var isZooming: Bool
        
        let metadata: ImageProvider
        /// 图片地址
        let url: URL
        
        private var cancellation: AnyCancellable?
        
        deinit {
            self.cancellation?.cancel()
        }
        
        convenience init(url: URL) {
            let base = NormalizationLayoutState(center: .center, rotationAngle: .zero, factor: 1.0)
            self.init(state: base, tempState: base, unionState: base, isDrag: false, isRotate: false, isZooming: false, metadata: url, url: url, cancellation: nil)
            
            let gesture = self._isDrag.projectedValue
                .combineLatest(self._isRotate.projectedValue, self._isZooming.projectedValue)
                .map { drag, rotate, zoom -> GestureState in
                    var states = [GestureState]()
                    if drag {
                        states.append(.dragging)
                    }
                    if rotate {
                        states.append(.rotate)
                    }
                    if zoom {
                        states.append(.zooming)
                    }
                    
                    return states.isEmpty ? .none:GestureState(states)
                }
            
            self.cancellation = self._state.projectedValue
                .combineLatest(self._tempState.projectedValue, gesture)
                .receive(on: DispatchQueue.main)
                .map { origin, temp, gestures in
                    gestures.contains(.dragging) || gestures.contains(.zooming) ? temp:origin
                }
                .assign(to: \.unionState, on: self)
        }
        
        convenience init(metadata: ImageProvider) {
            let base = NormalizationLayoutState(center: .center, rotationAngle: .zero, factor: 1.0)
            self.init(state: base, tempState: base, unionState: base, isDrag: false, isRotate: false, isZooming: false, metadata: metadata, url: metadata.url, cancellation: nil)
            
            let gesture = self._isDrag.projectedValue
                .combineLatest(self._isRotate.projectedValue, self._isZooming.projectedValue)
                .map { drag, rotate, zoom -> GestureState in
                    var states = [GestureState]()
                    if drag {
                        states.append(.dragging)
                    }
                    if rotate {
                        states.append(.rotate)
                    }
                    if zoom {
                        states.append(.zooming)
                    }
                    return states.isEmpty ? .none:GestureState(states)
                }
            
            self.cancellation = self._state.projectedValue
                .combineLatest(self._tempState.projectedValue, gesture)
                .receive(on: DispatchQueue.main)
                .map { origin, temp, gestures in
                    gestures.contains(.dragging) || gestures.contains(.zooming) ? temp:origin
                }
                .assign(to: \.unionState, on: self)
        }
    }
}


struct GestureState: OptionSet {
    let rawValue: UInt32
    
    static let dragging = GestureState(rawValue: 1)
    static let zooming = GestureState(rawValue: 0x10)
    static let rotate = GestureState(rawValue: 0x100)
    static let none = GestureState(rawValue: 0)
}
