//
//  File.swift
//  
//
//  Created by sonoma on 6/27/24.
//

import Foundation
import SwiftUI
import ChainBuilder

/// 图片绘制信息, 所有坐标是笛卡尔坐标系
@ChainBuiler
package struct ImageLayoutState: Equatable {
    /// 图片所在的中心点
    var center: Point
    /// 图片旋转角度
    var rotationAngle: Angle
    /// 图片原始大小
    var originSize: Size
    /// 缩放系数
    var factor: Double
    /// 图片缩/放后大小
    var size: Size {
        originSize.scale(factor)
    }
    /// 图片缩/放+旋转后的大小
    var bounds: Size {
        size.rotate(rotationAngle)
    }
    
    /// 图片缩/放+旋转+位移后的位置和大小
    var frame: Rects {
        let bounds = bounds
        let minX = center.x - bounds.width / 2.0
        let minY = center.y - bounds.height / 2.0
        let maxX = center.x + bounds.width / 2.0
        let maxY = center.y + bounds.height / 2.0
        
        return .init(topLeading: .init(x: minX, y: minY),
                     bottomLeading: .init(x: minX, y: maxY),
                     topTrailling: .init(x: maxX, y: minY),
                     bottomTrailling: .init(x: maxX, y: maxY))
    }
    
    func transform(_ transition: ImageTransition, in parentSize: Size) -> Self {
        ImageComposer(state: self, transition: transition).apply(in: parentSize)
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
}

@ChainBuiler
package struct ImageComposer {
    let state: ImageLayoutState
    let transition: ImageTransition
    
    func apply(in parentSize: Size) -> ImageLayoutState {
        switch transition.mode {
        case .scale(let factor, let anchor):
            let targetFactor = state.factor * factor
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
            return state.rotationAngle(
                state.rotationAngle + angle
            ).center(next)
        case .move(let offset):
            let nextCenter = state.center.offset(offset)
            return state.center(nextCenter)
        }
    }
}

/// (-w/2, h/2) -------------- (w/2, h/2)
///       |                        |
///       |                        |
///       |                        |
/// (-w/2, -h/2) -------------- (w/2, -h/2)
///
@ChainBuiler
package struct Rects {
    let topLeading: Rect
    let bottomLeading: Rect
    let topTrailling: Rect
    let bottomTrailling: Rect
    
    init(_ points: [CGPoint]) {
        guard points.count == 4 else {
            self.topLeading = .zero
            self.bottomLeading = .zero
            self.topTrailling = .zero
            self.bottomTrailling = .zero
            return
        }
        
        self.topLeading = .init(points[0])
        self.topTrailling = .init(points[1])
        self.bottomLeading = .init(points[2])
        self.bottomTrailling = .init(points[3])
    }
    
    var width: Double {
        topTrailling.x - topLeading.x
    }
    
    var height: Double {
        bottomLeading.y - topLeading.y
    }
}

package extension Rects {
    @ChainBuiler
    struct Rect {
        let x: Double
        let y: Double
        
        static let zero = Self(x: .zero, y: .zero)
        
        init(_ point: CGPoint) {
            self.x = point.x
            self.y = point.y
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

struct Point: Equatable {
    var x: Double
    var y: Double
    
    var cgValue: CGPoint {
        CGPoint(x: x, y: y)
    }
    
    static let zero = Point(x: .zero, y: .zero)
}

extension Point {
    @inlinable
    func offset(_ translation: Size) -> Point {
        Point(x: x + translation.width, y: y + translation.height)
    }
    
    func rotate(on center: Point, angle: Angle) -> Point {
        Point(x: center.x + (x - center.x) * cos(angle.radians) - (y - center.y) * sin(angle.radians),
              y: center.x + (x - center.x) * sin(angle.radians) - (y - center.y) * cos(angle.radians))
    }
}

@ChainBuiler
package struct Size: Equatable {
    var width: Double
    var height: Double
    
    static let zero = Size(width: .zero, height: .zero)
    
    var cgValue: CGSize {
        CGSize(width: width, height: height)
    }
    
    func scale(_ factor: Double) -> Self {
        Size(width: width * factor, height: height * factor)
    }
    
    func rotate(_ angle: Angle) -> Self {
        let points = [
            Point(x: -width / 2.0, y: height / 2.0),
            Point(x: width / 2.0, y: height / 2.0),
            Point(x: -width / 2.0, y: -height / 2.0),
            Point(x: width / 2.0, y: -height / 2.0)
        ]
        
        let rotations = points.map { point in
            Point(x: point.x * cos(angle.radians) - point.y * sin(angle.radians),
                  y: point.y * cos(angle.radians) + point.x * sin(angle.radians))
        }
        
        let minX = rotations.min(by: { $0.x < $1.x })?.x ?? 0
        let minY = rotations.min(by: { $0.y < $1.y })?.y ?? 0
        let maxX = rotations.max(by: { $0.x < $1.x })?.x ?? 0
        let maxY = rotations.max(by: { $0.y < $1.y })?.y ?? 0
        
        return Size(width: maxX - minX, height: maxY - minY)
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
    func fitting(_ parentSize: CGSize) -> CGFloat {
        if parentSize.width >= width, parentSize.height >= height {
            return 1.0
        }
        
        let aspectWidth = parentSize.width / width
        let aspectHeight = parentSize.height / height
        let aspectRatio = min(aspectWidth, aspectHeight)
        return aspectRatio
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

