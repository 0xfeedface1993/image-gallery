//
//  ScreenOutSheetModifier.swift
//  Animated
//
//  Created by sonoma on 7/15/24.
//

import SwiftUI

private struct DynamicParameter: Equatable {
    var translation: Double = 0
    var delta: Double = 0
}

public final class ScreenOutControl: ObservableObject {
    @Published public var isEnable: Bool = false
}

struct ScreenOutSheetModifier<V: View>: ViewModifier {
    private let contentBuilder: () -> V
    @Binding var isPresented: Bool
    var bounds: CGRect
    @State private var progress: Double = 0.0
    @GestureState private var dynamics: DynamicParameter = .init()
    @StateObject private var control = ScreenOutControl()
    @State private var isDragEnable = true
    
    init(isPresented: Binding<Bool>, bounds: CGRect, @ViewBuilder contentBuilder: @escaping () -> V) {
        self.contentBuilder = contentBuilder
        self._isPresented = isPresented
        self.bounds = bounds
    }
    
    func body(content: Content) -> some View {
        contentView(content)
            .simultaneousGesture(
                dragGesture
            )
            .environmentObject(control)
    }
    
    private var dummyGesture: some Gesture {
        TapGesture()
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dynamics, body: { value, state, transaction in
                if state.translation > 0, isDragEnable {
                    var distance = value.translation.height
                    if distance < 200 {
                        return
                    }
                    distance -= 200
                    //                        if value.translation.height > 68 {
                    //                            distance = value.translation.height
                    //                        }   else    {
                    //                            distance = sin(value.translation.height / 68 * CGFloat.pi / 2.0) * value.translation.height
                    //                        }
                    state.delta = distance - state.translation
                    state.translation = distance
                }   else    {
                    state.translation = value.translation.height
                }
            })
            .onEnded({ _ in
                withAnimation(.smooth) {
                    if progress < 0.7 {
                        isPresented = false
                        progress = 0
                    } else {
                        isPresented = true
                        progress = 1
                    }
                }
            })
    }
    
    func contentView(_ content: Content) -> some View {
        content.modifier(
            ScreenOutProgressModifier(edge: .bottom, progress: progress, bounds: bounds, viewBuilder: contentBuilder)
        )
        .onChange(of: isPresented) { newValue in
            withAnimation(.smooth) {
                progress = newValue ? 1.0:0.0
            }
        }
        .onChange(of: dynamics) { newValue in
            if newValue.delta == 0 {
                return
            }
            
            let candidate = progress - newValue.delta / bounds.height
            if candidate > 0, candidate < 1 {
                var transaction = Transaction()
                transaction.isContinuous = true
                transaction.animation = .interpolatingSpring(stiffness: 30, damping: 20)
                withTransaction(transaction) {
                    progress = candidate
                }
            }
        }
        .onPreferenceChange(ScreenOutControlKey.self, perform: { newValue in
            isDragEnable = newValue
        })
    }
}

public extension View {
    @ViewBuilder
    func screenOutSheet<V: View>(isPresented: Binding<Bool>, bounds: CGRect, @ViewBuilder content: @escaping () -> V) -> some View {
        modifier(ScreenOutSheetModifier(isPresented: isPresented, bounds: bounds, contentBuilder: content))
    }
}

public struct ScreenOutControlKey: PreferenceKey {
    public static func reduce(value: inout Value, nextValue: () -> Value) {
        
    }
    
    public static var defaultValue: Bool = true
}
