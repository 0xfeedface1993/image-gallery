//
//  TwoTapsViewModifier.swift
//  S8Blocker
//
//  Created by Peter on 2024/6/20.
//

import SwiftUI

struct TwoTapsViewModifier: ViewModifier {
    var action: () -> Void
    
    func body(content: Content) -> some View {
        content.gesture(
            TapGesture(count: 2)
                .onEnded({ _ in
                    action()
                })
        )
    }
}
