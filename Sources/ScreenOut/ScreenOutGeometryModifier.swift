//
//  SwiftUIView.swift
//  ImageGallery
//
//  Created by sonoma on 7/22/24.
//

import SwiftUI
import OSLog
import Core

fileprivate let logger = Logger(subsystem: "ScreenOut", category: "ScreenOutGeometryModifier")

private struct DynamicParameter: Equatable {
    var translation: Double = 0
    var delta: Double = 0
}

public struct ScreenOutGeometryModifier<V: View, Q: Hashable>: ViewModifier {
    @State private var cachedFrames = [AnyHashable: CGRect]()
    @State private var progress: Double = 0.0
    @Binding var activeID: Q?
    @State private var internalID: Q?
    @State private var sourceFrame: CGRect = .zero
    @State private var targetFrame: CGRect = .zero
    var targetBuilder: (Q) -> V
    @Namespace private var namespace
    private let smoothAnimate = Animation.smooth(duration: 0.35)
    @StateObject private var shareSatate = GestureShareState()
    @State private var bounds = CGRect.zero
    
    public init(activeID: Binding<Q?>, @ViewBuilder targetBuilder: @escaping (Q) -> V) {
        self._activeID = activeID
        self.targetBuilder = targetBuilder
    }
    
    public func body(content: Content) -> some View {
        content
            .background(content: {
                GeometryReader { proxy in
                    Color.clear.preference(key: PresentedContentSizeKey.self, value: proxy.frame(in: .named(NameCoordinateSpace.value(namespace))))
                }
            })
            .onPreferenceChange(PresentedContentSizeKey.self, perform: { newValue in
                bounds = newValue
                let text = "content \(type(of: content)) bounds: \(newValue)"
                logger.debug("\(text)")
            })
            .onPreferenceChange(ImageFrameKey.self) { newValue in
                cachedFrames = newValue
            }
            .modifier(
                ScreenOutGeometryProgressModifier(progress: progress,
                                                  bounds: bounds,
                                                  viewBuilder: {
                                                      if let internalID {
                                                          AnyView(targetBuilder(internalID))
                                                      } else {
                                                          AnyView(EmptyView())
                                                      }
                                                  },
                                                  sourceFrame: sourceFrame,
                                                  targetFrame: targetFrame,
                                                  onTap: {
                                                      activeID = nil
                                                  })
            )
            .onChange(of: activeID) { newValue in
                guard let newValue, var frame = cachedFrames[newValue] else {
                    logger.debug("unable find cache frame for \("\(String(describing: newValue))")")
                    internalAnimate(to: 0, updateID: true, id: nil)
                    return
                }
                frame.origin.x = frame.midX - bounds.midX
                frame.origin.y = frame.midY - bounds.midY
                sourceFrame = frame
                
                let ratio = frame.height / frame.width
                let screenWidthRatio = frame.width / bounds.width
                let screenHeightRatio = frame.height / bounds.height
                
                let (width, height) = screenWidthRatio > screenHeightRatio
                    ? (bounds.width, bounds.width * ratio)
                    : (bounds.height / ratio, bounds.height)
                
                let size = CGSize(width: width, height: height)
                targetFrame = CGRect(origin: .zero, size: size)
                
                let text = "from \(frame) to \(targetFrame)"
                logger.debug("\(text)")
                internalAnimate(to: 1, updateID: true, id: newValue)
            }
            .gesture(DragGesture(minimumDistance: 0)
                .onEnded({ state in
                    let velocity = state.velocity.height
                    let offset = state.translation.height
                    logger.debug("drag velocity \(velocity), offset \(offset)")
                    if abs(velocity) > 500, abs(offset) > 100 {
                        activeID = nil
                    }
                }), isEnabled: !shareSatate.current.isScaled)
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
            .namespaceTag(NameCoordinateSpace.value(namespace))
            .environment(\.screenOutCoordinateSpace, .value(namespace))
            .environmentObject(shareSatate)
            .navigationBarBackportHidden(internalID != nil)
            .task {
                internalID = activeID
            }
    }
    
    private func internalAnimate(to nextProgress: Double, updateID: Bool = false, id: Q? = nil) {
        if #available(iOS 17.0, macOS 14.0, *) {
            withAnimation {
                progress = nextProgress
                if nextProgress > 0, internalID == nil {
                    internalID = id
                }
            } completion: {
                if updateID {
                    internalID = id
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
                try await Task.sleep(nanoseconds: 1_000_000_000)
                internalID = id
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

fileprivate struct PresentedContentSizeKey: PreferenceKey {
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        
    }
    
    static var defaultValue: CGRect = .zero
}
