//
//  DragableViewModifiler.swift
//  S8Blocker
//
//  Created by Peter on 2024/6/20.
//

import SwiftUI

struct DragViewModifiler: ViewModifier {
    @Binding var base: ImageLayoutState
    @Binding var dynamic: ImageLayoutState
    @Binding var isDrag: Bool
    @Environment(\.imageProgressTransformer) private var imageProgressTransformer
    @Environment(\.imageTargetTransformer) private var imageTargetTransformer
    
    var containerSize: Size
    
    func body(content: Content) -> some View {
        content.gesture(
            DragGesture()
                .onChanged({ value in
                    if !isDrag {
                        isDrag = true
                    }
                    
                    let validTranslation = imageProgressTransformer(base, value.translation.size)
                    dynamic = base.transform(.init(mode: .move(validTranslation)), in: containerSize)
                })
                .onEnded({ value in
                    let swap = base
                    let validTranslation = imageTargetTransformer(swap, dynamic, value.translation.size)
                    let next = swap.transform(.init(mode: .move(validTranslation)), in: containerSize)
                    withAnimation(.spring().speed(1.5)) {
                        isDrag = false
                        dynamic = next
                        base = next
                    }
                })
        )
    }
}
