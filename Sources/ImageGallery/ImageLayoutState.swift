//
//  File.swift
//  
//
//  Created by sonoma on 6/27/24.
//

import Foundation
import SwiftUI
import ChainBuilder
import Core

@ChainBuiler
package struct LayoutParameter {
    let originSize: Size
    let parentSize: Size
    
    init(_ imageSize: Size, window: Size) {
        self.originSize = imageSize
        self.parentSize = window
    }
    
    func restore(_ normalization: NormalizedLayoutState) -> ImageLayoutDiscription {
        let factor = factor(normalization.factor)
        let size = originSize.scale(factor)
        let bounds = size.rotate(normalization.rotationAngle)
        let center = point(normalization.center)
        let frame = frame(bounds, center: center)
        return ImageLayoutDiscription(center: center, rotationAngle: normalization.rotationAngle, originSize: originSize, factor: factor, size: size, bounds: size, frame: frame)
    }
    
    func factor(_ value: Double) -> Double {
        value * originSize.fitting(parentSize)
    }
    
    func point(_ value: Point) -> Point {
        value.cgValue.applying(CGAffineTransform(scaleX: parentSize.width, y: parentSize.height)).point
    }
    
    func frame(_ bounds: Size, center: Point) -> Rects {
        let minX = center.x - bounds.width / 2.0
        let minY = center.y - bounds.height / 2.0
        let maxX = center.x + bounds.width / 2.0
        let maxY = center.y + bounds.height / 2.0
        
        return .init(topLeading: .init(x: minX, y: minY),
                     bottomLeading: .init(x: minX, y: maxY),
                     topTrailling: .init(x: maxX, y: minY),
                     bottomTrailling: .init(x: maxX, y: maxY))
    }
    
    func normalized(_ transition: ImageTransition) -> ImageTransition {
        switch transition.mode {
        case .scale(let scale, let value):
            return ImageTransition(mode: .scale(scale, normalization(value)))
        case .rotate(let angle, let value):
            return ImageTransition(mode: .rotate(angle, normalization(value)))
        case .move(let value):
            return ImageTransition(mode: .move(normalization(value)))
        }
    }
    
    func normalization(_ value: Size) -> Size {
        parentSize.normalized(value)
    }
    
    func normalization(_ value: Point) -> Point {
        parentSize.normalization(value)
    }
}

package struct ImageTransition: Equatable {
    enum Mode: Equatable {
        static func == (lhs: ImageTransition.Mode, rhs: ImageTransition.Mode) -> Bool {
            switch (lhs, rhs) {
            case (.scale(let l, let lp), .scale(let r, let rp)):
                return r == l && lp == rp
            case (.rotate(let l, let lp), .rotate(let r, let rp)):
                return r == l && lp == rp
            case (.move(let l), .move(let r)):
                return r == l
            default:
                return false
            }
        }
        
        case scale(Double, Point)
        case rotate(Angle, Point)
        case move(Size)
    }
    let mode: Mode
    
    init(mode: Mode) {
        self.mode = mode
    }
    
    static func create(_ mode: Mode) -> Self {
        .init(mode: mode)
    }
    
    func control(by option: LayoutOptions) -> Self {
        switch mode {
        case .scale(let scale, let point):
            return .create(.scale(option.scaleLevel.control(scale), point))
        case .rotate:
            return self
        case .move:
            return self
        }
    }
}

extension NormalizedLayoutState {
    func transform(_ transition: ImageTransition) -> Self {
        ImageComposer(state: self, transition: transition).apply()
    }
}

@ChainBuiler
package struct ImageComposer {
    let state: NormalizedLayoutState
    let transition: ImageTransition
    
    func apply() -> NormalizedLayoutState {
        switch transition.mode {
        case .scale(let factor, let anchor):
            let targetFactor = factor * state.factor
            let next = state.center.cgValue.applying(
                CGAffineTransform(translationX: -anchor.x, y: -anchor.y)
                    .concatenating(.init(scaleX: factor, y: factor))
                    .concatenating(.init(translationX: anchor.x, y: anchor.y))
            ).point
            return state.center(next).factor(targetFactor)
        case .rotate(let angle, let anchor):
            let next = state.center.cgValue.applying(
                CGAffineTransform(translationX: -anchor.x, y: -anchor.y)
                    .concatenating(.init(rotationAngle: angle.radians))
                    .concatenating(.init(translationX: anchor.x, y: anchor.y))
            ).point
            let nextAngle = Angle(degrees: state.rotationAngle.degrees + angle.degrees)
//
//            if nextAngle.degrees < 0 {
//                nextAngle = Angle(degrees: 360 + nextAngle.degrees)
//            }
            
//            print("base angle \(state.rotationAngle), rotate degress \(nextAngle.degrees)")
            return state.rotationAngle(nextAngle).center(next)
        case .move(let offset):
            let nextCenter = state.center.offset(offset)
            return state.center(nextCenter)
        }
    }
}

extension CGPoint {
    @inlinable
    func offset(_ translation: CGSize) -> CGPoint {
        CGPoint(x: x + translation.width, y: y + translation.height)
    }
    
    var point: Point {
        Point(x: x, y: y)
    }
}

extension CGSize {
    var size: Size {
        Size(width: width, height: height)
    }
}

extension CGImage {
    var size: Size {
        Size(width: Double(width), height: Double(height))
    }
}

extension GeometryProxy {
    var center: CGPoint {
        .init(x: size.width / 2.0, y: size.height / 2.0)
    }
}

extension CGSize {
    func normalized(in size: CGSize) -> CGSize {
        CGSize(width: width / size.width, height: height / size.height)
    }
    
    func fitting(_ parentSize: CGSize) -> CGFloat {
        let normalized = self.normalized(in: parentSize)
        return 1 / max(normalized.width, normalized.height)
    }
    
    func shrink(in size: CGSize) -> CGSize {
        scaled(fitting(size))
    }
    
    func move(_ offset: CGSize) -> CGSize {
        CGSize(width: width + offset.width, height: height + offset.height)
    }
}

extension Size {
    func scaled(_ value: Double) -> Self {
        cgValue.scaled(value).size
    }
    
    func fitting(_ parentSize: Size) -> Double {
        cgValue.fitting(parentSize.cgValue)
    }
    
    func normalized(in size: Size) -> Size {
        Size(width: width / size.width, height: height / size.height)
    }
}

extension CGSize {
    func scaled(_ value: CGFloat) -> Self {
        applying(.scaled(value))
    }
}

extension CGAffineTransform {
    static func scaled(_ value: CGFloat) -> Self {
        .init(scaleX: value, y: value)
    }
}

