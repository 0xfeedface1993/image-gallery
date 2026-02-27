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
                if progress > 0 || sourceFrame != .zero || targetFrame != .zero {
                    viewBuilder()
                        .onTapGesture(perform: onTap)
                        .modifier(
                            ScreenOutGeometryEmbeedModifier(progress: progress,
                                                            bounds: bounds,
                                                            sourceFrame: sourceFrame,
                                                            targetFrame: targetFrame)
                        )
                        .clipped()
                }
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
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let safeBoundsWidth = max(bounds.width, 1)
        let safeBoundsHeight = max(bounds.height, 1)
        let fallbackTarget = CGRect(
            x: -safeBoundsWidth / 2,
            y: -safeBoundsHeight / 2,
            width: safeBoundsWidth,
            height: safeBoundsHeight
        )
        let resolvedTarget = targetFrame.width > 0 && targetFrame.height > 0 ? targetFrame : fallbackTarget
        let resolvedSource = sourceFrame.width > 0 && sourceFrame.height > 0 ? sourceFrame : resolvedTarget
        let currentFrame = ScreenOutGeometryMath.interpolatedFrame(from: resolvedSource, to: resolvedTarget, progress: progress)
        // At steady state, the gallery container should occupy the full screen.
        // This keeps header and gestures bound to the screen, not the image frame.
        let displayFrame = progress >= 0.999 ? fallbackTarget : currentFrame
        let positionX = safeBoundsWidth / 2 + displayFrame.midX
        let positionY = safeBoundsHeight / 2 + displayFrame.midY

        ZStack(alignment: .center) {
            Color.black.ignoresSafeArea().opacity(progress)

            content
                .frame(width: max(displayFrame.width, 1), height: max(displayFrame.height, 1))
                .position(x: positionX, y: positionY)
                .environment(\.animateProgress, progress)
        }
        .frame(width: safeBoundsWidth, height: safeBoundsHeight)
        .clipped()
    }
}
