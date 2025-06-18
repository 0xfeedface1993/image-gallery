//
//  SwiftUIView.swift
//  ImageGallery
//
//  Created by sonoma on 7/24/24.
//

import SwiftUI
import ChainBuilder
import OSLog

fileprivate let logger = Logger(subsystem: "Enviroments", category: "EnvironmentValues")

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
    public struct Rect: Equatable, Sendable {
        public let x: Double
        public let y: Double
        
        public nonisolated static let zero = Self(x: .zero, y: .zero)
        
        init(_ point: CGPoint) {
            self.x = point.x
            self.y = point.y
        }
    }
}

@ChainBuiler
public struct Point: Equatable, CustomStringConvertible, Sendable {
    public var x: Double
    public var y: Double
    
    public var cgValue: CGPoint {
        CGPoint(x: x, y: y)
    }
    
    public nonisolated static let zero = Point(x: .zero, y: .zero)
    public nonisolated static let center = Point(x: 0.5, y: 0.5)
    
    public var description: String {
        "x: \(x), y: \(y)"
    }
}

public extension Point {
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
public struct Size: Equatable, Sendable {
    public var width: Double
    public var height: Double
    
    public nonisolated static let zero = Size(width: .zero, height: .zero)
    public nonisolated static let `default` = Size(width: 1.0, height: 1.0)
    public nonisolated static let unknown = Size(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
    
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

/// 归一化的图片绘制信息
@ChainBuiler
public struct NormalizedLayoutState: Equatable, Sendable {
    /// 图片所在的中心点
    public var center: Point
    /// 图片旋转角度
    public var rotationAngle: Angle
    /// 缩放系数
    public var factor: Double
    
    public nonisolated static let `default` = Self(center: .center, rotationAngle: .zero, factor: 1.0, isGestureEnable: false)
    
    public func frame(with imageSize: Size) -> Rects {
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
    
    public func bounds(with imageSize: Size) -> Size {
        imageSize.scale(factor / max(imageSize.width, imageSize.height)).rotate(rotationAngle)
    }
    
    public var isGestureEnable: Bool
    
    public func relativeScreenFactor(_ imageSize: Size, in size: Size) -> Double {
        let fittingFactor = imageSize.fitting(size)
        return factor / fittingFactor
    }
}

package extension CGSize {
    func normalized(in size: CGSize) -> CGSize {
        CGSize(width: width / size.width, height: height / size.height)
    }
    
    func fitting(_ parentSize: CGSize) -> CGFloat {
        let normalized = self.normalized(in: parentSize)
        guard !normalized.width.isNaN, !normalized.height.isNaN, normalized.width > 0, normalized.height > 0 else {
            return .zero
        }
        return 1 / max(normalized.width, normalized.height)
    }
    
    func shrink(in size: CGSize) -> CGSize {
        scaled(fitting(size))
    }
    
    func move(_ offset: CGSize) -> CGSize {
        CGSize(width: width + offset.width, height: height + offset.height)
    }
}

package extension CGPoint {
    @inlinable
    func offset(_ translation: CGSize) -> CGPoint {
        CGPoint(x: x + translation.width, y: y + translation.height)
    }
    
    var point: Point {
        Point(x: x, y: y)
    }
}

package extension CGSize {
    var size: Size {
        Size(width: width, height: height)
    }
}

package extension Size {
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


package final class GestureShareState: ObservableObject {
//    @Published package var current = NormalizedLayoutState(center: .center, rotationAngle: .zero, factor: 1, isGestureEnable: false)
    @Published package var isDismissEnable = false
    
    package init() {
        
    }
}

public enum NameCoordinateSpace: Hashable {
    case none
    case value(Namespace.ID)
}

#if swift(>=5.10)
extension EnvironmentValues {
    @Entry package var animateProgress: Double = 0.0
    @Entry package var screenOutCoordinateSpace: NameCoordinateSpace = .none
    @Entry public var galleryOptions: LayoutOptions = LayoutOptions(capability: .all, scaleLevel: .default, rotateMode: .bounce, dragMode: .bounce, panelEnable: true)
    @Entry public var events: (Events) -> Void = { _ in
        logger.warning("default EvnentsKey value")
    }
}
#else
package struct AnimateProgressKey: EnvironmentKey {
    public static var defaultValue: Double = 0.0
}

extension EnvironmentValues {
    package var animateProgress: Double {
        get { self[AnimateProgressKey.self] }
        set { self[AnimateProgressKey.self] = newValue }
    }
}

struct NamedCoordinateSpaceKey: EnvironmentKey {
    static var defaultValue: NameCoordinateSpace = .none
}

extension EnvironmentValues {
    var screenOutCoordinateSpace: NameCoordinateSpace {
        get { self[NamedCoordinateSpaceKey.self] }
        set { self[NamedCoordinateSpaceKey.self] = newValue }
    }
}

public struct LayoutOptionsKey: EnvironmentKey {
    public static var defaultValue = LayoutOptions(capability: .all, scaleLevel: .default, rotateMode: .bounce, dragMode: .bounce, panelEnable: true)
}

extension EnvironmentValues {
    public var galleryOptions: LayoutOptions {
        set { self[LayoutOptionsKey.self] = newValue }
        get { self[LayoutOptionsKey.self] }
    }
}

public struct EvnentsKey: EnvironmentKey {
    public static var defaultValue: (Events) -> Void = { _ in
        logger.warning("default EvnentsKey value")
    }
}

extension EnvironmentValues {
    public var events: (Events) -> Void {
        set { self[EvnentsKey.self] = newValue }
        get { self[EvnentsKey.self] }
    }
}
#endif

package struct ImageFrameKey: @MainActor PreferenceKey {
    @MainActor package static var defaultValue = [AnyHashable: CGRect]()
    
    package static func reduce(value: inout [AnyHashable : CGRect], nextValue: () -> [AnyHashable : CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct ImageFrameModifier<T: Hashable>: ViewModifier {
    @Environment(\.screenOutCoordinateSpace) var screenOutCoordinateSpace
    let geometryID: T
    
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
//                Color.clear.preference(key: ImageFrameKey.self, value: [geometryID: proxy.frame(in: .named(screenOutCoordinateSpace))])
                Color.clear.preference(key: ImageFrameKey.self, value: [geometryID: proxy.frame(in: .global)])
            }
        }
    }
}

public extension View {
    @ViewBuilder
    func geometry<T: Hashable>(id: T) -> some View {
        modifier(ImageFrameModifier(geometryID: id))
    }
}

