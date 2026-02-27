//
//  SwiftUIView.swift
//  ImageGallery
//
//  Created by sonoma on 7/22/24.
//

import SwiftUI
import OSLog
import Core
import Foundation

fileprivate let logger = Logger(subsystem: "ScreenOut", category: "ScreenOutGeometryModifier")
fileprivate let screenOutDebugLogsEnabled =
    ProcessInfo.processInfo.environment["IG_DEBUG_LOGS"] == "1" ||
    ProcessInfo.processInfo.arguments.contains("-ig-debug-logs")

@inline(__always)
fileprivate func screenOutFmt(_ value: CGFloat) -> String {
    String(format: "%.3f", value)
}

@inline(__always)
fileprivate func screenOutFmt(_ value: Double) -> String {
    String(format: "%.3f", value)
}

@inline(__always)
fileprivate func screenOutRectDescription(_ rect: CGRect) -> String {
    "{x:\(screenOutFmt(rect.minX)),y:\(screenOutFmt(rect.minY)),w:\(screenOutFmt(rect.width)),h:\(screenOutFmt(rect.height)),midX:\(screenOutFmt(rect.midX)),midY:\(screenOutFmt(rect.midY))}"
}

@inline(__always)
fileprivate func screenOutDebugLog(_ message: @autoclosure () -> String) {
    guard screenOutDebugLogsEnabled else {
        return
    }
    let text = message()
    print(text)
    screenOutAppendToFile(text)
}

@inline(__always)
fileprivate func screenOutAppendToFile(_ line: String) {
    let path = NSTemporaryDirectory().appending("ig_debug.log")
    let url = URL(fileURLWithPath: path)
    guard let data = "\(line)\n".data(using: .utf8) else {
        return
    }

    if !FileManager.default.fileExists(atPath: path) {
        try? data.write(to: url, options: .atomic)
        return
    }

    guard let handle = try? FileHandle(forWritingTo: url) else {
        return
    }
    defer {
        try? handle.close()
    }
    _ = try? handle.seekToEnd()
    try? handle.write(contentsOf: data)
}

public struct ScreenOutGeometryModifier<V: View, Q: Hashable>: ViewModifier {
    @State private var cachedFrames = [AnyHashable: CGRect]()
    @State private var progress: Double = 0.0
    @Binding var activeID: Q?
    @State private var internalID: Q?
    @State private var sourceFrame: CGRect = .zero
    @State private var targetFrame: CGRect = .zero
    var targetBuilder: (Q) -> V
    private let smoothAnimate = Animation.easeInOut(duration: 0.24)
    @StateObject private var shareSatate = GestureShareState()
    @State private var bounds = CGRect.zero
    @State private var navigationBar: Bool = false
    
    public init(activeID: Binding<Q?>, @ViewBuilder targetBuilder: @escaping (Q) -> V) {
        self._activeID = activeID
        self.targetBuilder = targetBuilder
    }
    
    public func body(content: Content) -> some View {
        content
            .background(content: {
                GeometryReader { proxy in
                    Color.clear
//                        .preference(key: PresentedContentSizeKey.self, value: proxy.frame(in: .named(NameCoordinateSpace.value(namespace))))
                        .preference(key: PresentedContentSizeKey.self, value: proxy.frame(in: .global))
                }
            })
            .onPreferenceChange(PresentedContentSizeKey.self, perform: { newValue in
                bounds = newValue
                screenOutDebugLog("IG_DEBUG_SO boundsUpdated bounds=\(screenOutRectDescription(newValue))")
//                let text = "content \(type(of: content)) bounds: \(newValue)"
//                logger.debug("\(text)")
            })
            .onPreferenceChange(ImageFrameKey.self) { newValue in
                cachedFrames = newValue
                if let activeID {
                    let activeKey = AnyHashable(activeID)
                    if let activeFrame = newValue[activeKey] {
                        screenOutDebugLog(
                            "IG_DEBUG_SO cacheUpdated activeID=\(String(describing: activeID)) frame=\(screenOutRectDescription(activeFrame)) total=\(newValue.count)"
                        )
                    } else {
                        screenOutDebugLog(
                            "IG_DEBUG_SO cacheUpdated activeID=\(String(describing: activeID)) frame=missing total=\(newValue.count)"
                        )
                    }
                } else {
                    screenOutDebugLog("IG_DEBUG_SO cacheUpdated activeID=nil total=\(newValue.count)")
                }
            }
            .modifier(
                ScreenOutGeometryProgressModifier(progress: progress,
                                                  bounds: bounds,
                                                  viewBuilder: {
                                                      if let internalID {
                                                          targetBuilder(internalID)
                                                      }
                                                  },
                                                  sourceFrame: sourceFrame,
                                                  targetFrame: targetFrame,
                                                  onTap: {
                                                      activeID = nil
                                                  })
            )
            .onChange(of: activeID) { newValue in
                if let newValue, let frame = cachedFrames[newValue] {
                    let bounds = self.bounds
                    let source = ScreenOutGeometryMath.sourceFrameInOverlayCoordinates(sourceFrame: frame, in: bounds)
                    sourceFrame = source

                    targetFrame = calculateTargetFrame(from: source, in: bounds)
                    screenOutDebugLog(
                        "IG_DEBUG_SO activeIDChanged value=\(String(describing: newValue)) bounds=\(screenOutRectDescription(bounds)) rawSource=\(screenOutRectDescription(frame)) sourceInOverlay=\(screenOutRectDescription(sourceFrame)) target=\(screenOutRectDescription(targetFrame))"
                    )

                    let text = "from \(source) to \(targetFrame)"
                    logger.debug("\(text)")
                    internalAnimate(to: 1, updateID: true, id: newValue)
                    return
                }

                if let internalID, let frame = cachedFrames[AnyHashable(internalID)] {
                    let bounds = self.bounds
                    let source = ScreenOutGeometryMath.sourceFrameInOverlayCoordinates(sourceFrame: frame, in: bounds)
                    sourceFrame = source
                    targetFrame = calculateTargetFrame(from: source, in: bounds)
                    screenOutDebugLog(
                        "IG_DEBUG_SO dismissToSource internalID=\(String(describing: internalID)) bounds=\(screenOutRectDescription(bounds)) rawSource=\(screenOutRectDescription(frame)) sourceInOverlay=\(screenOutRectDescription(sourceFrame)) target=\(screenOutRectDescription(targetFrame))"
                    )
                    internalAnimate(to: 0, updateID: true, id: nil)
                    return
                }

                logger.debug("unable find cache frame for \("\(String(describing: newValue))")")
                screenOutDebugLog("IG_DEBUG_SO activeIDChanged value=\(String(describing: newValue)) sourceFrame=missing")
                sourceFrame = .zero
                targetFrame = .zero
                internalAnimate(to: 0, updateID: true, id: nil)
            }
            .onChange(of: progress) { newProgress in
                guard screenOutDebugLogsEnabled else {
                    return
                }
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
                let currentFrame = ScreenOutGeometryMath.interpolatedFrame(from: resolvedSource, to: resolvedTarget, progress: newProgress)
                let displayFrame = newProgress >= 0.999 ? fallbackTarget : currentFrame
                screenOutDebugLog(
                    "IG_DEBUG_SO progress=\(screenOutFmt(newProgress)) bounds=\(screenOutRectDescription(bounds)) source=\(screenOutRectDescription(resolvedSource)) target=\(screenOutRectDescription(resolvedTarget)) current=\(screenOutRectDescription(currentFrame)) display=\(screenOutRectDescription(displayFrame))"
                )
            }
//            .gesture(DragGesture(minimumDistance: 0)
//                .onEnded({ state in
//                    let velocity = state.velocity.height
//                    let offset = state.translation.height
//                    logger.debug("drag velocity \(velocity), offset \(offset)")
//                    if abs(velocity) > 500, abs(offset) > 100 {
//                        activeID = nil
//                    }
//                }), isEnabled: shareSatate.isDismissEnable)
//            .simultaneousGesture(
//                DragGesture(minimumDistance: 0)
//                    .onEnded({ state in
//                        guard !shareSatate.current.isScaled else {
//                            return
//                        }
//                        let velocity = state.velocity.height
//                        let offset = state.translation.height
//                        logger.debug("drag velocity \(velocity), offset \(offset)")
//                        if abs(velocity) > 500, abs(offset) > 100 {
//                            activeID = nil
//                        }
//                    })
//            )
//            .namespaceTag(NameCoordinateSpace.value(namespace))
//            .environment(\.screenOutCoordinateSpace, .value(namespace))
            .environmentObject(shareSatate)
            .navigationBarBackportHidden(navigationBar)
#if os(iOS)
            .onChange(of: internalID, perform: { newValue in
                if UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac {
                    if navigationBar {
                        navigationBar = false                        
                    }
                } else {
                    navigationBar = newValue != nil
                }
            })
#endif
            .task {
                internalID = activeID
            }
    }
    
    private func calculateTargetFrame(from sourceFrame: CGRect, in bounds: CGRect) -> CGRect {
        ScreenOutGeometryMath.targetFrame(for: sourceFrame, in: bounds)
    }

    private func internalAnimate(to nextProgress: Double, updateID: Bool = false, id: Q? = nil) {
        screenOutDebugLog(
            "IG_DEBUG_SO animateStart from=\(screenOutFmt(progress)) to=\(screenOutFmt(nextProgress)) updateID=\(updateID) id=\(String(describing: id)) internalID=\(String(describing: internalID))"
        )
        if #available(iOS 17.0, macOS 14.0, *) {
            withAnimation(smoothAnimate) {
                progress = nextProgress
                if nextProgress > 0, internalID == nil {
                    internalID = id
                }
            } completion: {
                if updateID {
                    internalID = id
                    if id == nil {
                        shareSatate.isDismissEnable = false
                    } else {
                        shareSatate.isDismissEnable = true
                    }
                    screenOutDebugLog(
                        "IG_DEBUG_SO animateCompletion progress=\(screenOutFmt(progress)) internalID=\(String(describing: internalID)) dismissEnable=\(shareSatate.isDismissEnable)"
                    )
                }
            }
        } else {
            // Fallback on earlier versions
            withAnimation(smoothAnimate) {
                progress = nextProgress
                if nextProgress > 0, internalID == nil {
                    internalID = id
                }
            }
            if !updateID {
                return
            }
            Task {
                try await Task.sleep(nanoseconds: 300_000_000)
                internalID = id
                if id == nil {
                    shareSatate.isDismissEnable = false
                } else {
                    shareSatate.isDismissEnable = true
                }
                screenOutDebugLog(
                    "IG_DEBUG_SO animateCompletionFallback progress=\(screenOutFmt(progress)) internalID=\(String(describing: internalID)) dismissEnable=\(shareSatate.isDismissEnable)"
                )
            }
        }
    }
}

extension View {
    @ViewBuilder
    public func screenOutGeometry<V: View, D: Hashable>(activeID: Binding<D?>, @ViewBuilder content: @escaping (D) -> V) -> some View {
        modifier(
            ScreenOutGeometryModifier(activeID: activeID, targetBuilder: content)
        )
    }
}

extension View {
    @ViewBuilder
    func namespaceTag<T: Hashable>(_ tag: T) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            self.coordinateSpace(NamedCoordinateSpace.named(tag))
        } else {
            // Fallback on earlier versions
            self.coordinateSpace(name: tag)
        }
    }
}

fileprivate struct PresentedContentSizeKey: @MainActor PreferenceKey {
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        
    }
    
    @MainActor static var defaultValue: CGRect = .zero
}
