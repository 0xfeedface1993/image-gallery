//
//  File.swift
//  
//
//  Created by sonoma on 6/27/24.
//

import Foundation
import SwiftUI
import URLImage

struct ZoomingView: View {
    var image: CGImage
    @ObservedObject var model: GallrayViewModel.Item
    
    @State private var unionPosition: Point
    @State private var unionFactor: CGFloat
    @State private var unionAngle: Angle
    
    init(image: CGImage, model: GallrayViewModel.Item) {
        self.image = image
        self.model = model
        let state = model.state
        self.unionPosition = state.center
        self.unionFactor = state.factor
        self.unionAngle = state.rotationAngle
    }
    
    var body: some View {
        GeometryReader(content: { geometry in
            imageView
                .scaleEffect(
                    LayoutParameter(originSize: image.size, parentSize: geometry.size.size).factor(unionFactor)
                )
                .rotationEffect(unionAngle)
                .position(
                    LayoutParameter(originSize: image.size, parentSize: geometry.size.size).point(unionPosition).cgValue
                )
                .modifier(
                    ZoomViewModifiler(model: model, parameter: LayoutParameter(originSize: image.size, parentSize: geometry.size.size))
                )
                .modifier(
                    TwoTapsViewModifier(action: {
                        model.reset()
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
            GIFImage(model.url) {
                
            } inProgress: { progress in
                
            } failure: { error, completion in
                
            } content: { content in
                content
            }
        }   else    {
            Image(image, scale: 1.0, label: Text(model.url.absoluteString))
        }
    }

    private func updateState(_ state: NormalizationLayoutState) {
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
