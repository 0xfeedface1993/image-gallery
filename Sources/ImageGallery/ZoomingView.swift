//
//  File.swift
//  
//
//  Created by sonoma on 6/27/24.
//

import Foundation
import SwiftUI

struct ZoomingView: View {
    var image: CGImage
    let parameter: LayoutParameter
    @ObservedObject var model: GallrayViewModel.Item
    
    @State private var unionPosition: Point
    @State private var unionFactor: CGFloat
    @State private var unionAngle: Angle
    
    private var fittingScale: CGFloat {
        Double(max(image.width, image.height))
    }
    
    init(image: CGImage, parameter: LayoutParameter, model: GallrayViewModel.Item) {
        self.image = image
        self.parameter = parameter
        self.model = model
        let state = parameter.restore(model.state)
        self.unionPosition = state.center
        self.unionFactor = state.factor
        self.unionAngle = state.rotationAngle
    }
    
    var body: some View {
        Image(image, scale: 1.0, label: Text(model.url.absoluteString))
            .scaleEffect(unionFactor)
            .rotationEffect(unionAngle)
            .position(unionPosition.cgValue)
            .modifier(
                ZoomViewModifiler(model: model, parameter: parameter)
            )
            .modifier(
                TwoTapsViewModifier(action: {
                    model.state = .default
                })
            )
            .onChange(of: model.unionState, perform: { newValue in
                let restored = parameter.restore(newValue)
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
            })
    }
}
