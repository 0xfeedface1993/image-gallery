//
//  SwiftUIView.swift
//  ImageGallery
//
//  Created by sonoma on 7/14/24.
//

import SwiftUI

struct CoverBackgroundColor: EnvironmentKey {
    static var defaultValue: Color { .clear }
}

extension EnvironmentValues {
    var coverBackgroundColor: Color {
        get { self[CoverBackgroundColor.self] }
        set { self[CoverBackgroundColor.self] = newValue }
    }
}

public extension View {
    /// Set custom color for gallary background, default is `clear`.
    /// - Parameter color: new background color
    func gallaryCoverBackgroundColor(_ color: Color) -> some View {
        environment(\.coverBackgroundColor, color)
    }
}
