//
//  File.swift
//  ImageGallery
//
//  Created by york on 2026/2/23.
//

import Foundation
import SwiftUI

public struct GeometryChangeViewModifier: ViewModifier {
    @Environment(\.scrollCoordinateSpaceName) private var scrollCoordinateSpaceName
    
    public var onAppearChange: (Double) -> Void
    
    public init(_ onAppearChange: @escaping (Double) -> Void) {
        self.onAppearChange = onAppearChange
    }
    
    public func body(content: Content) -> some View {
        let coordinateSpaceName = scrollCoordinateSpaceName
        if #available(iOS 16.0, macOS 13.0, *) {
            content.onGeometryChange(for: Double.self, of: { proxy in
                if #available(macOS 14.0, iOS 17.0, *) {
                    let frame = proxy.frame(in: .scrollView)
                    let bounds = proxy.bounds(of: .scrollView)
                    guard let bounds else {
                        return 0
                    }
                    let interact = bounds.intersection(frame)
                    let insetProgress = interact.width / bounds.width
                    return insetProgress
                } else {
                    // Fallback on earlier versions
                    let frame: CGRect
                    switch coordinateSpaceName {
                    case .global:
                        frame = proxy.frame(in: .global)
                    case .namespace(let id):
                        frame = proxy.frame(in: .named(AnyHashable(id)))
                    }
                    let bounds = CGRect(origin: .zero, size: proxy.size)
                    let interact = bounds.intersection(frame)
                    let insetProgress = interact.width / bounds.width
                    return insetProgress
                }
            }, action: onAppearChange)
        } else {
            // Fallback on earlier versions
            content.background {
                GeometryReader { proxy in
                    if #available(iOS 17.0, macOS 14.0, *) {
                        Color.clear
                            .onChange(of: frame(proxy, in: scrollCoordinateSpaceName)) { _, frame in
                                onFrameChange(frame, size: proxy.size)
                            }
                    } else {
                        // Fallback on earlier versions
                        Color.clear
                            .onChange(of: frame(proxy, in: scrollCoordinateSpaceName)) { frame in
                                onFrameChange(frame, size: proxy.size)
                            }
                    }
                }
            }
        }
    }
    
    private func onFrameChange(_ frame: CGRect, size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
        let interact = bounds.intersection(frame)
        let insetProgress = interact.width / bounds.width
        onAppearChange(insetProgress)
    }

    private func frame(_ proxy: GeometryProxy, in space: CoordinatorNameSpace) -> CGRect {
        switch space {
        case .global:
            return proxy.frame(in: .global)
        case .namespace(let id):
            return proxy.frame(in: .named(AnyHashable(id)))
        }
    }
}

extension EnvironmentValues {
    @Entry public var scrollCoordinateSpaceName = CoordinatorNameSpace.global
}

public enum CoordinatorNameSpace: Sendable {
    case global
    case namespace(any Hashable & Sendable)
    
    var undelyCoordinateSpace: CoordinateSpace {
        switch self {
        case .global:
            return .global
        case .namespace(let id):
            return .named(AnyHashable(id))
        }
    }
}
