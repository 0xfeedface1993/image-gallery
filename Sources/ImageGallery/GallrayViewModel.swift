//
//  File.swift
//  
//
//  Created by sonoma on 6/30/24.
//

import Foundation
import ChainBuilder
import Combine
import SwiftUI
import OSLog
import Core

fileprivate let logger = Logger(subsystem: "ViewModel", category: "GallrayViewModel")
package let uiQueue = DispatchQueue(label: "ui.workload")

final class GallrayViewModel: ObservableObject {
    /// 当前页数
    @Published var page: Int
    /// 水平卷轴偏移量
    @Published private var contentOffset: Point
    /// 图片列表
    @Published var images: [Item]
    /// UI上需要显示的水平卷轴偏移量
    @Published var unionOffset: Point
    
    @Published var isDefaultCoverDisplay: Bool
    
    init(_ data: [ImageProvider]) {
        self.page = 0
        self.contentOffset = .zero
        self.images = data.map(Item.init(metadata:))
        self.unionOffset = .zero
        self.isDefaultCoverDisplay = false
    }
    
    var currentImage: Item? {
        guard images.endIndex > page, images.startIndex <= page else {
            return nil
        }
        return images[page]
    }
    
    func send(_ event: UserAction) {
        switch event {
        case .tap:
            isDefaultCoverDisplay.toggle()
        case .doubleTap:
            guard let item = currentImage else {
                return
            }
            item.reset()
        case .doubleTapOutside:
            guard let item = currentImage else {
                return
            }
            item.reset()
        case .drag(let translation, let state, let options):
            guard let item = currentImage else {
                return
            }
            switch state {
            case .start:
                break
            case .change:
                onProgress(item, translation: translation, state: state, galleryOptions: options)
            case .end:
                onEnd(item, translation: translation, state: state, galleryOptions: options)
            }
        case .scale:
            break
        case .rotate:
            break
        case .move:
            break
        }
    }
    
    func reset() {
        images.forEach { item in
            item.reset()
        }
        contentOffset = Point(x: Double(-page), y: 0)
    }
    
    private func onProgress(_ item: Item, translation: Size, state: UserGestureState, galleryOptions: LayoutOptions) {
        let bounds = item.state.bounds(with: item.imageSize)
        guard bounds.width <= 1, bounds.height <= 1 else {
            item.unionState = item.state.transform(.init(mode: .move(translation)))
            return
        }
        
        let next = contentOffset.offset(translation.height(0))
        unionOffset = next
        onOffsetChange(next.x)
    }
    
    private func onEnd(_ item: Item, translation: Size, state: UserGestureState, galleryOptions: LayoutOptions) {
        let bounds = item.state.bounds(with: item.imageSize)
        guard bounds.width <= 1, bounds.height <= 1 else {
            var nextState = item.state.transform(.init(mode: .move(translation)))
            if galleryOptions.dragMode == .bounce {
                let frame = nextState.frame(with: item.imageSize)
                
                let minX = frame.topLeading.x
                let maxX = frame.topTrailling.x
                let minY = frame.topLeading.y
                let maxY = frame.bottomLeading.y
                
                if frame.width >= 1 {
                    if minX > 0 {
                        nextState.center.x -= minX
                    }
                    
                    if maxX < 1 {
                        nextState.center.x += 1 - maxX
                    }
                }
                
                if frame.height >= 1 {
                    if minY > 0, frame.height >= 1 {
                        nextState.center.y -= minY
                    }
                    
                    if maxY < 1, frame.height >= 1 {
                        nextState.center.y += (1 - maxY)
                    }
                }
                
                if frame.width < 1 {
                    nextState = nextState.center(nextState.center.x(0.5))
                }
                
                if frame.height < 1 {
                    nextState = nextState.center(nextState.center.y(0.5))
                }
            }
            item.state = nextState
            item.unionState = nextState
            return
        }
        
        let maybe = contentOffset.offset(translation.height(0))
        let next = predictPageableOffset(maybe)
        logger.debug("final move state: \(next)")
        contentOffset = next
        unionOffset = next
        onOffsetChange(next.x)
    }
    
    func move(to page: Int) {
        let images = images
        if images.count > 0, page >= images.startIndex, page < images.endIndex {
            let next = Point(x: Double(-page), y: 0)
            contentOffset = next
            unionOffset = next
            self.page = indexOf(next.x)
        }
    }
    
    private func onOffsetChange(_ newValue: CGFloat) {
        page = indexOf(newValue)
    }
    
    func indexOf(_ x: CGFloat) -> Int {
        guard x < 0 else {
            return 0
        }
        
        let next = Int(abs(x.rounded(.towardZero)))
        return max(min(images.count - 1, next), 0)
    }
    
    func predictPageableOffset(_ predictValue: Point) -> Point {
        let lastOffset = contentOffset
        var offset = min(max(predictValue.x, -Double(images.count - 1)), 0)
        let remind = abs(offset.truncatingRemainder(dividingBy: 1.0))
        offset += lastOffset.x > offset && remind > (1.0 / 5.0) ? -(1 - remind):remind
        return Point(x: offset, y: 0)
    }
}

extension GallrayViewModel {
    @ChainBuiler
    final class Item: ObservableObject {    
        @Published var state: NormalizedLayoutState
        @Published var unionState: NormalizedLayoutState
        @Published var imageSize: Size
        @Published var layoutUpdate: Bool
        
        let metadata: ImageProvider
        /// 图片地址
        let url: URL
        
        convenience init(url: URL) {
            let base = NormalizedLayoutState(center: .center, rotationAngle: .zero, factor: 1.0, isGestureEnable: false)
            self.init(state: base, unionState: base, imageSize: .default, layoutUpdate: false, metadata: url, url: url)
        }
        
        convenience init(metadata: ImageProvider) {
            let base = NormalizedLayoutState(center: .center, rotationAngle: .zero, factor: 1.0, isGestureEnable: false)
            self.init(state: base, unionState: base, imageSize: .default, layoutUpdate: false, metadata: metadata, url: metadata.url)
        }
        
        func reset() {
            state = .default
            unionState = .default
            layoutUpdate.toggle()
        }
        
        func update(_ rotateAction: UserAction, scaleAction: UserAction, layoutOptions: LayoutOptions) {
            let next = updateState(rotateAction, scaleAction: scaleAction, layoutOptions: layoutOptions)
            switch next {
            case .temp(let temp):
                unionState = temp
            case .all(_, let state):
                self.state = state
                unionState = state
            case .none:
                break
            }
        }
        
        private func updateState(_ rotateAction: UserAction, scaleAction: UserAction, layoutOptions: LayoutOptions) -> CombineUpdate {
            if !layoutOptions.capability.contains([.scale, .rotate]) {
                return .none
            }
            
            guard case let .scale(scaleCenter, factor, scaleState, _) = scaleAction,
                  case let .rotate(rotateCenter, rotate, rotateState, _) = rotateAction else {
                return .none
            }
            
            var newState = state
            
            if layoutOptions.capability.contains(.scale) {
                if scaleState == .change {
                    newState = newState.transform(.create(.scale(factor, scaleCenter)))
                }   else    {
                    let origin = newState
                    let intentFactor = origin.factor * factor
                    let fitting = 1 / max(imageSize.width, imageSize.height)
                    let relativeImageFactor = intentFactor * fitting
                    let limitedFactor = layoutOptions.scaleLevel.control(relativeImageFactor)
                    let operationFactor = limitedFactor / fitting / origin.factor
                    newState = origin.transform(.create(.scale(operationFactor, scaleCenter)))
                }
            }
            
            if layoutOptions.capability.contains(.rotate) {
                let rotatedState = newState.transform(.create(.rotate(rotate, rotateCenter)))
                
                if rotateState == .change || layoutOptions.rotateMode == .unlimited {
                    newState = rotatedState
                }
            }
            
            if rotateState == .end, scaleState == .end {
                if layoutOptions.dragMode == .bounce {
                    let frame = newState.frame(with: imageSize)
                    if frame.width <= 1 {
                        newState = newState.center(newState.center.x(0.5))
                    }
                    if frame.height <= 1 {
                        newState = newState.center(newState.center.y(0.5))
                    }
                }
                
                return .all(temp: newState, state: newState)
            }
            
            return .temp(newState)
        }
    }
    
    func isDipslayWindow(_ image: Item, progress: Double) -> Bool {
        let images = self.images
        let page = self.page
        guard let index = images.firstIndex(where: { $0.url == image.url }) else {
            return false
        }
        
        if index == page {
            return true
        }
        
        if progress < 1.0 {
            return false
        }
        
        let beforeIndex = max(images.index(before: page), images.indices.lowerBound)
        let afterIndex = min(images.index(after: page), images.indices.upperBound)
        
        let display = beforeIndex <= index && index <= afterIndex
        if display {
            logger.info("index \(index) diplayed, current page \(page)")
        }   else    {
            logger.info("index \(index) not displayed, current page \(page), valid range \(beforeIndex) <= index <= \(afterIndex)")
        }
        
        return display
    }
}


struct GestureState: OptionSet {
    let rawValue: UInt32
    
    static let dragging = GestureState(rawValue: 1)
    static let zooming = GestureState(rawValue: 0x10)
    static let rotate = GestureState(rawValue: 0x100)
    static let none = GestureState([])
}
