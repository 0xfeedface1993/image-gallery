//
//  SwiftUIView.swift
//  
//
//  Created by sonoma on 7/6/24.
//

import SwiftUI

struct DefaultPanelView: View {
    @ObservedObject var model: GallrayViewModel
    @State private var isDisplay: Bool
    var onTapBack: () -> Void
    
    init(model: GallrayViewModel, onTapBack: @escaping () -> Void) {
        self.model = model
        self.isDisplay = model.isDefaultCoverDisplay
        self.onTapBack = onTapBack
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack {
                Spacer()
                Text("\(model.page + 1) / \(model.images.count)")
                    .foregroundColor(.white)
                    .bold()
                Spacer()
            }
            .frame(height: 44)
            .overlay(alignment: .leading) {
                Button(action: onTapBack) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.white)
                }
            }
            .background {
                Color.black.ignoresSafeArea(edges: .top).opacity(0.5).onTapGesture {
                    print("block tap")
                }
            }
            
            Spacer()
        }
        .opacity(isDisplay ? 1.0:0)
        .onChange(of: model.isDefaultCoverDisplay) { newValue in
            withAnimation(.spring(blendDuration: 0.2).speed(1.5)) {
                isDisplay = newValue
            }
        }
    }
}
