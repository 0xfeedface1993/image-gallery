//
//  File.swift
//  
//
//  Created by sonoma on 6/27/24.
//

import Foundation
import SwiftUI
import URLImage
import OSLog

fileprivate let logger = Logger(subsystem: "UI", category: "ZoomingView")

struct ZoomingView<Content: View>: View {
    var image: CGImage
    @ObservedObject var model: GallrayViewModel.Item
    
    @State private var unionPosition: Point
    @State private var unionFactor: CGFloat
    @State private var unionAngle: Angle
    @Environment(\.events) private var events
    
    var attachView: (GallrayViewModel.Item, ImageLayoutDiscription) -> Content
    
    init(image: CGImage, model: GallrayViewModel.Item, @ViewBuilder attachView: @escaping (GallrayViewModel.Item, ImageLayoutDiscription) -> Content) {
        self.image = image
        self.model = model
        let state = model.unionState
        self.unionPosition = state.center
        self.unionFactor = state.factor
        self.unionAngle = state.rotationAngle
        self.attachView = attachView
    }
    
    var body: some View {
        GeometryReader(content: { geometry in
            imageView
                .overlayed({
                    attachView(model, LayoutParameter(image.size, window: geometry.size.size).restore(model.unionState))
                })
                .scaleEffect(
                    LayoutParameter(image.size, window: geometry.size.size).factor(unionFactor)
                )
                .rotationEffect(unionAngle)
                .position(
                    LayoutParameter(image.size, window: geometry.size.size).point(unionPosition).cgValue
                )
                .modifier(
                    ZoomViewModifiler(model: model, parameter: LayoutParameter(image.size, window: geometry.size.size))
                )
                .modifier(
                    TwoTapsViewModifier(action: {
                        model.reset()
                        events(.doubleTap(model.metadata))
                    })
                )
                .onChange(of: model.unionState, perform: { newValue in
                    updateState(newValue)
                })
        })
    }
    
    @ViewBuilder
    private var imageView: some View {
        if model.url.absoluteString.contains(".gif") {
            GIFImage(model.url) { } inProgress: { _ in } failure: { error, completion in } content: { $0 }
        }   else    {
            Image(image, scale: 1.0, label: Text(model.url.absoluteString))
        }
    }

    private func updateState(_ state: NormalizedLayoutState) {
        let restored = state
        let factor = restored.factor
        let center = restored.center
        let updatePosition = unionPosition != center
        let updateFactor = unionFactor != factor
        let updateRotate = unionAngle != restored.rotationAngle
        
        guard updatePosition || updateFactor || updateRotate else {
            return
        }
        
        withAnimation(.spring().speed(1.5)) {
            if updatePosition {
                unionPosition = center
            }
            
            if updateFactor {
                unionFactor = factor
            }
            
            if updateRotate {
                unionAngle = restored.rotationAngle
            }
        }
    }
}
