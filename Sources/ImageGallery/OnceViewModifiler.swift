//
//  File.swift
//  
//
//  Created by sonoma on 6/27/24.
//

import SwiftUI

struct OnceViewModifiler: ViewModifier {
    var action: () async -> Void
    
    @State private var isLoaded = false
    
    func body(content: Content) -> some View {
        if #available(iOS 15.0, macOS 12.0, *) {
            return content.task {
                await action()
            }
        } else {
            // Fallback on earlier versions
            return content.onAppear {
                guard !isLoaded else {
                    return
                }
                isLoaded = true
                Task {
                    await action()
                }
            }
        }
    }
}

extension View {
    @ViewBuilder
    func once(_ completion: @escaping () async -> Void) -> some View {
        modifier(OnceViewModifiler(action: completion))
    }
}
