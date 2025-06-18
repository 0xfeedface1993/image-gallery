//
//  File.swift
//  
//
//  Created by sonoma on 7/6/24.
//

import Foundation
import ChainBuilder
import OSLog
import SwiftUI

public protocol ImageProvider {
    var url: URL { get }
}

extension URL: ImageProvider {
    public var url: URL {
        self
    }
}

public enum UserGestureState {
    case start
    case change
    case end
}

package enum UserAction {
    case tap(location: Point, layoutOptions: LayoutOptions)
    case doubleTap(location: Point)
    case doubleTapOutside
    case drag(translation: Size, state: UserGestureState, layoutOptions: LayoutOptions)
    case scale(location: Point, magnification: Double, state: UserGestureState, layoutOptions: LayoutOptions)
    case rotate(location: Point, angle: Angle, state: UserGestureState, layoutOptions: LayoutOptions)
    case move(Size)
}

public struct GestureEvent {
    public let item: ImageProvider
    public let states: [StateChange]
    
    package init(item: ImageProvider, states: [StateChange]) {
        self.item = item
        self.states = states
    }
}

extension GestureEvent {
    public enum Gesture {
        case scale(Double)
        case rotate(Angle)
        case move(CGSize)
    }
    
    public struct StateChange {
        public let change: Gesture
        public let state: UserGestureState
        
        package init(change: Gesture, state: UserGestureState) {
            self.change = change
            self.state = state
        }
    }
}

public enum Events {
    case tap(ImageProvider?)
    case doubleTap(ImageProvider)
    case gestures(GestureEvent)
    case deviceOrientationChange(ImageProvider)
    case moveToPage(ImageProvider)
}


@ChainBuiler
public struct LayoutOptions: Equatable {
    public var capability: Capability
    public var scaleLevel: ScaleLevelOptions
    public var rotateMode: RotateMode
    public var dragMode: DragMode
    public var panelEnable: Bool
}

extension LayoutOptions {
    public struct Capability: Equatable, OptionSet, Sendable {
        public var rawValue: UInt
        
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        
        public nonisolated static let scale = Capability(rawValue: 1)
        public nonisolated static let rotate = Capability(rawValue: 1 << 1)
        public nonisolated static let dragging = Capability(rawValue: 1 << 2)
        
        public nonisolated static let all = scale.union(rotate).union(dragging)
    }
    
    public enum RotateMode {
        case unlimited
        case bounce
    }
    
    public enum DragMode {
        case unlimited
        case bounce
    }
}

extension LayoutOptions {
    @ChainBuiler
    public struct ScaleLevelOptions: Equatable, Sendable {
        /// 最大缩放系数
        private var _max: Double
        /// 最小缩放系数
        private var _min: Double
        
        /// 最大缩放系数
        public var max: Double {
            get { _max }
            set { _max = Swift.max(Swift.max(Swift.min(4, newValue), 0.1), _min) }
        }
        /// 最小缩放系数
        public var min: Double {
            get { _min }
            set { _min = Swift.min(Swift.max(Swift.min(4, newValue), 0.1), _max) }
        }
        
        public nonisolated static let `default` = ScaleLevelOptions(max: 2.0, min: 0.8)
        
        package func control(_ value: Double) -> Double {
            Swift.max(Swift.min(value, self.max), self.min)
        }
    }
}
