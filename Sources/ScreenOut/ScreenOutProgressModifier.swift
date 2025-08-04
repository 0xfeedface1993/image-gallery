//
//  ScreenOutProgressModifier.swift
//  Animated
//
//  Created by sonoma on 7/15/24.
//

import SwiftUI

#if swift(>=6.2)
struct ScreenOutProgressModifier<V: View>: ViewModifier, @MainActor Animatable {
    let edge: Edge
    var progress: Double
    var bounds: CGRect
    var viewBuilder: () -> V
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .overlay(content: {
                if progress > 0.01 {
                    viewBuilder()
                        .modifier(ScreenOutModifier(edge: edge, progress: 1 - progress, bounds: bounds))
                }
            })
    }
}
#else
struct ScreenOutProgressModifier<V: View>: ViewModifier, @preconcurrency Animatable {
    let edge: Edge
    var progress: Double
    var bounds: CGRect
    var viewBuilder: () -> V
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .overlay(content: {
                if progress > 0.01 {
                    viewBuilder()
                        .modifier(ScreenOutModifier(edge: edge, progress: 1 - progress, bounds: bounds))
                }
            })
    }
}
#endif
