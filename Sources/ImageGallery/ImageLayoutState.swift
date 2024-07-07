//
//  File.swift
//  
//
//  Created by sonoma on 6/27/24.
//

import Foundation
import SwiftUI
import ChainBuilder

@ChainBuiler
public struct ImageLayoutDiscription: Equatable {
    /// 图片所在的中心点
    public let center: Point
    /// 图片旋转角度
    public let rotationAngle: Angle
    /// 图片原始大小
    public let originSize: Size
    /// 缩放系数
    public let factor: Double
    /// 图片缩/放后大小
    public let size: Size
    /// 图片缩/放+旋转后的大小
    public let bounds: Size
    /// 图片缩/放+旋转+位移后的位置和大小
    public let frame: Rects
}

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

/// 归一化的图片绘制信息
@ChainBuiler
package struct NormalizedLayoutState: Equatable {
    /// 图片所在的中心点
    var center: Point
    /// 图片旋转角度
    var rotationAngle: Angle
    /// 缩放系数
    var factor: Double
    
    static let `default` = Self(center: .center, rotationAngle: .zero, factor: 1.0)
    
    func transform(_ transition: ImageTransition) -> Self {
        ImageComposer(state: self, transition: transition).apply()
    }
    
    func frame(with imageSize: Size) -> Rects {
        let bounds = bounds(with: imageSize)
        let minX = center.x - bounds.width / 2.0
        let minY = center.y - bounds.height / 2.0
        let maxX = center.x + bounds.width / 2.0
        let maxY = center.y + bounds.height / 2.0
        
        return .init(topLeading: .init(x: minX, y: minY),
                     bottomLeading: .init(x: minX, y: maxY),
                     topTrailling: .init(x: maxX, y: minY),
                     bottomTrailling: .init(x: maxX, y: maxY))
    }
    
    func bounds(with imageSize: Size) -> Size {
        imageSize.scale(factor / max(imageSize.width, imageSize.height)).rotate(rotationAngle)
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
        case .rotate(let angle, let point):
            return self
        case .move(let size):
            return self
        }
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
            var nextAngle = Angle(degrees: state.rotationAngle.degrees + angle.degrees)
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

/// (-w/2, h/2) -------------- (w/2, h/2)
///       |                        |
///       |                        |
///       |                        |
/// (-w/2, -h/2) -------------- (w/2, -h/2)
///
@ChainBuiler
public struct Rects: Equatable {
    public let topLeading: Rect
    public let bottomLeading: Rect
    public let topTrailling: Rect
    public let bottomTrailling: Rect
    
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
    
    public var width: Double {
        topTrailling.x - topLeading.x
    }
    
    public var height: Double {
        bottomLeading.y - topLeading.y
    }
}

extension Rects {
    @ChainBuiler
    public struct Rect: Equatable {
        public let x: Double
        public let y: Double
        
        public static let zero = Self(x: .zero, y: .zero)
        
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

@ChainBuiler
public struct Point: Equatable, CustomStringConvertible {
    public var x: Double
    public var y: Double
    
    public var cgValue: CGPoint {
        CGPoint(x: x, y: y)
    }
    
    public static let zero = Point(x: .zero, y: .zero)
    public static let center = Point(x: 0.5, y: 0.5)
    
    public var description: String {
        "x: \(x), y: \(y)"
    }
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
public struct Size: Equatable {
    public var width: Double
    public var height: Double
    
    public static let zero = Size(width: .zero, height: .zero)
    public static let `default` = Size(width: 1.0, height: 1.0)
    public static let unknown = Size(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
    
    public var cgValue: CGSize {
        CGSize(width: width, height: height)
    }
    
    public func scale(_ factor: Double) -> Self {
        Size(width: width * factor, height: height * factor)
    }
    
    public func rotate(_ angle: Angle) -> Self {
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
    
    public func normalization(_ point: Point) -> Point {
        Point(x: point.x / width, y: point.y / height)
    }
    
    public func normalized(_ value: Size) -> Size {
        Size(width: value.width / width, height: value.height / height)
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

