//
//  File.swift
//  
//
//  Created by sonoma on 6/30/24.
//

import Foundation
import SwiftUI

struct OverlyerViewModifier: ViewModifier {
    var builder: () -> any View
    
    func body(content: Content) -> some View {
        if #available(iOS 15.0, macOS 12.0, *) {
            return content.overlay(content: {
                AnyView(builder())
            })
        } else {
            // Fallback on earlier versions
            return content.overlay(AnyView(builder()))
        }
    }
}

extension View {
    @ViewBuilder
    func overlayed(@ViewBuilder _ builder: @escaping () -> any View) -> some View {
        modifier(OverlyerViewModifier(builder: builder))
    }
}
