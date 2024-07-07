//
//  File.swift
//  
//
//  Created by sonoma on 7/6/24.
//

import Foundation
import ChainBuilder

@ChainBuiler
public struct LayoutOptions: Equatable {
    public var capability: Capability
    public var scaleLevel: ScaleLevelOptions
    public var rotateMode: RotateMode
    public var dragMode: DragMode
}

extension LayoutOptions {
    public struct Capability: Equatable, OptionSet {
        public var rawValue: UInt
        
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        
        public static let scale = Capability(rawValue: 1)
        public static let rotate = Capability(rawValue: 1 << 1)
        public static let dragging = Capability(rawValue: 1 << 2)
        
        public static let all = scale.union(rotate).union(dragging)
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
    public struct ScaleLevelOptions: Equatable {
        /// 最大缩放系数
        private var _max: Double
        /// 最小缩放系数
        private var _min: Double
        
        /// 最大缩放系数
        public var max: Double {
            get { _max }
            set { Swift.max(Swift.max(Swift.min(4, newValue), 0.1), _min) }
        }
        /// 最小缩放系数
        public var min: Double {
            get { _min }
            set { Swift.min(Swift.max(Swift.min(4, newValue), 0.1), _max) }
        }
        
        public static let `default` = ScaleLevelOptions(max: 2.0, min: 0.8)
        
        func control(_ value: Double) -> Double {
            Swift.max(Swift.min(value, self.max), self.min)
        }
    }
}

import SwiftUI

public struct LayoutOptionsKey: EnvironmentKey {
    public static var defaultValue = LayoutOptions(capability: .all, scaleLevel: .default, rotateMode: .bounce, dragMode: .bounce)
}

extension EnvironmentValues {
    public var galleryOptions: LayoutOptions {
        set { self[LayoutOptionsKey.self] = newValue }
        get { self[LayoutOptionsKey.self] }
    }
}
