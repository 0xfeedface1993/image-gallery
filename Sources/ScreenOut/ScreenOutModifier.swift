//
//  ScreenOutModifier.swift
//  Animated
//
//  Created by sonoma on 7/15/24.
//

import SwiftUI

struct ScreenOutModifier: ViewModifier, Animatable {
    let edge: Edge
    var progress: Double
    var bounds: CGRect
    @State private var rect = CGRect.zero
    
    var animatableData: Double {
        get {
            progress
        }
        
        set {
            progress = newValue
        }
    }
    
    func body(content: Content) -> some View {
        content
//            .transformEffect(calculateAffineTransform())
            .opacity(1 - progress)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: PresentedContentSizeKey.self, value: proxy.frame(in: .global))
                }
            }
            .onPreferenceChange(PresentedContentSizeKey.self) {
                rect = $0
            }
    }
    
    private func calculateAffineTransform() -> CGAffineTransform {
        let target: CGPoint
        switch edge {
        case .trailing:
            target = CGPoint(x: bounds.maxX, y: 0)
        case .leading:
            target = CGPoint(x: -rect.maxX, y: 0)
        case .top:
            target = CGPoint(x: 0, y: -rect.maxY)
        case .bottom:
            target = CGPoint(x: 0, y: bounds.maxY)
        }
        return .init(translationX: target.x * progress, y: target.y * progress)
    }
}

fileprivate struct PresentedContentSizeKey: PreferenceKey {
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        
    }
    
    static var defaultValue: CGRect = .zero
}

extension AnyTransition {
    static func screenOut(edge: Edge, bounds: CGRect) -> AnyTransition {
        AnyTransition.modifier(active: ScreenOutModifier(edge: edge, progress: 1.0, bounds: bounds),
                               identity: ScreenOutModifier(edge: edge, progress: 0.0, bounds: bounds))
    }
}
