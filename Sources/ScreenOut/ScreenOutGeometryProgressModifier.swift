//
//  ScreenOutGeometryProgressModifier.swift
//  Animated
//
//  Created by sonoma on 7/22/24.
//

import SwiftUI
import Core

struct ScreenOutGeometryProgressModifier<V: View>: ViewModifier, @MainActor Animatable {
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
    
    init(progress: Double, bounds: CGRect, @ViewBuilder viewBuilder: @escaping () -> V, sourceFrame: CGRect, targetFrame: CGRect, onTap: @escaping () -> Void) {
        self.progress = progress
        self.bounds = bounds
        self.viewBuilder = viewBuilder
        self.sourceFrame = sourceFrame
        self.targetFrame = targetFrame
        self.onTap = onTap
    }

    func body(content: Content) -> some View {
        content
            .overlay {
//                if progress > 0.0001 {
                    viewBuilder()
                        .onTapGesture(perform: onTap)
                        .modifier(
                            ScreenOutGeometryEmbeedModifier(progress: progress,
                                                            bounds: bounds,
                                                            sourceFrame: sourceFrame,
                                                            targetFrame: targetFrame)
                        )
//                }
            }
    }
}

extension View {
    @ViewBuilder
    public func navigationBarBackportHidden(_ hidden: Bool) -> some View {
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
            toolbarVisibility(hidden ? .hidden:.visible, for: .automatic)
        } else {
            // Fallback on earlier versions
            if #available(macOS 13.0, *) {
                toolbar(hidden ? .hidden:.visible, for: .automatic)
            } else {
                // Fallback on earlier versions
                self
            }
        }
#endif
    }
}

struct ScreenOutGeometryEmbeedModifier: ViewModifier, @MainActor Animatable {
    var progress: Double
    var bounds: CGRect
    var sourceFrame: CGRect
    var targetFrame: CGRect
    @Environment(\.galleryOptions) private var galleryOptions
    @Environment(\.screenOutCoordinateSpace) private var screenOutCoordinateSpace
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .center) {
            Color.black.ignoresSafeArea().opacity(progress)
            
            content
                .frame(width: sourceFrame.width + (targetFrame.width - sourceFrame.width) * progress, height: bounds.height)
                .offset(x: sourceFrame.origin.x + (targetFrame.origin.x - sourceFrame.origin.x) * progress,
                        y: sourceFrame.origin.y + (targetFrame.origin.y - sourceFrame.origin.y) * progress)
//                .frame(width: sourceFrame.width,
//                       height: sourceFrame.height)
//                .position(x: sourceFrame.origin.x,
//                          y: sourceFrame.origin.y)
                .environment(\.animateProgress, progress)
//                .frame(width: targetFrame.width,
//                       height: targetFrame.height)
//                .offset(x: targetFrame.origin.x,
//                        y: targetFrame.origin.y)
        }
    }
}
