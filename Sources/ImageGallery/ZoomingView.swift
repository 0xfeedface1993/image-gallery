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
import Core

fileprivate let logger = Logger(subsystem: "UI", category: "ZoomingView")

//struct

struct ZoomingView<Content: View>: View {
    var imageSize: Size
    @ObservedObject var model: GallrayViewModel.Item
    
    @State private var unionPosition: Point = .center
    @State private var unionFactor: CGFloat = 1
    @State private var unionAngle: Angle = .zero
    @Environment(\.events) private var events
    @Environment(\.galleryOptions) private var galleryOptions
    
//    @State private var combineTransform = CGAffineTransform.identity
    
    var attachView: (GallrayViewModel.Item, ImageLayoutDiscription) -> Content
    
    init(imageSize: Size, model: GallrayViewModel.Item, @ViewBuilder attachView: @escaping (GallrayViewModel.Item, ImageLayoutDiscription) -> Content) {
        self.imageSize = imageSize
        self.model = model
        self.attachView = attachView
        let state = model.unionState
        self.unionPosition = state.center
        self.unionFactor = state.factor
        self.unionAngle = state.rotationAngle
    }
    
    var body: some View {
        GeometryReader(content: { geometry in
            imageView
                .overlayed({
                    attachView(model, LayoutParameter(imageSize, window: geometry.size.size).restore(model.unionState))
                })
//                .transformEffect(combineTransform)
                .scaleEffect(
                    LayoutParameter(imageSize, window: geometry.size.size).factor(unionFactor)
                )
                .rotationEffect(unionAngle)
                .position(
                    LayoutParameter(imageSize, window: geometry.size.size).point(unionPosition).cgValue
                )
                .modifier(
                    ZoomViewModifiler(model: model, parameter: LayoutParameter(imageSize, window: geometry.size.size))
                )
                .modifier(
                    TwoTapsViewModifier(action: {
                        if model.state.factor < 1.0 {
                            model.reset()
                        }   else if model.state.factor > 1.0    {
                            model.reset()
                        }   else    {
                            model.update(.rotate(location: .center, angle: .zero, state: .end, layoutOptions: galleryOptions),
                                         scaleAction: .scale(location: .center, magnification: 2.0, state: .end, layoutOptions: galleryOptions),
                                         layoutOptions: galleryOptions)
                        }
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
//            Image(image, scale: 1.0, label: Text(model.url.absoluteString))
            URLImage(model.url, content: { $0 })
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
        
        withAnimation(.smooth) {
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
