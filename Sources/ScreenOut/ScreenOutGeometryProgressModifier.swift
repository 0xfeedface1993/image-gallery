//
//  ScreenOutGeometryProgressModifier.swift
//  Animated
//
//  Created by sonoma on 7/22/24.
//

import SwiftUI
import Core

struct ScreenOutGeometryProgressModifier<V: View>: ViewModifier, Animatable {
    var progress: Double
    var bounds: CGRect
    var viewBuilder: () -> V
    var sourceFrame: CGRect
    var targetFrame: CGRect
    var onTap: () -> Void
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .overlay(content: {
                if progress > 0.0001 {
                    viewBuilder()
                        .navigationBarBackportHidden(true)
                        .onTapGesture(perform: onTap)
                        .modifier(
                            ScreenOutGeometryEmbeedModifier(progress: progress,
                                                            bounds: bounds,
                                                            sourceFrame: sourceFrame,
                                                            targetFrame: targetFrame)
                        )
                }
            })
    }
}

extension View {
    @ViewBuilder
    func navigationBarBackportHidden(_ hidden: Bool) -> some View {
#if os(iOS) || os(watchOS) || os(visionOS)
        if #available(iOS 18.0, *) {
            toolbarVisibility(hidden ? .hidden:.visible, for: .navigationBar)
        } else {
            // Fallback on earlier versions
            if #available(iOS 16.0, *) {
                toolbar(hidden ? .hidden:.visible, for: .navigationBar)
            } else {
                // Fallback on earlier versions
                navigationBarHidden(hidden)
            }
        }
#elseif os(macOS)
        if #available(macOS 15.0, *) {
            toolbarVisibility(hidden ? .hidden:.visible, for: .windowToolbar)
        } else {
            // Fallback on earlier versions
            if #available(macOS 13.0, *) {
                toolbar(hidden ? .hidden:.visible, for: .windowToolbar)
            } else {
                // Fallback on earlier versions
                self
            }
        }
#endif
    }
}

struct ScreenOutGeometryEmbeedModifier: ViewModifier, Animatable {
    var progress: Double
    var bounds: CGRect
    var sourceFrame: CGRect
    var targetFrame: CGRect
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .center) {
            Color.black.opacity(progress).ignoresSafeArea()
            
            content
                .frame(width: sourceFrame.width + (targetFrame.width - sourceFrame.width) * progress, height: bounds.height)
                .offset(x: sourceFrame.origin.x + (targetFrame.origin.x - sourceFrame.origin.x) * progress,
                        y: sourceFrame.origin.y + (targetFrame.origin.y - sourceFrame.origin.y) * progress)
                .environment(\.animateProgress, animatableData)
//                .frame(width: sourceFrame.width,
//                       height: sourceFrame.height)
//                .offset(x: sourceFrame.origin.x,
//                        y: sourceFrame.origin.y)
//                .frame(width: targetFrame.width,
//                       height: targetFrame.height)
//                .offset(x: targetFrame.origin.x,
//                        y: targetFrame.origin.y)
        }
    }
}
