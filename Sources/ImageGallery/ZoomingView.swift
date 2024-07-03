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
    @ObservedObject var model: GallrayViewModel.Item
    
    @State private var isLoaded: Bool
    @State private var unionPosition: CGPoint
    @State private var unionFactor: CGFloat
    @State private var unionAngle: Angle
    
    private var fittingScale: CGFloat {
        Double(max(image.width, image.height))
    }
    
    init(image: CGImage, model: GallrayViewModel.Item) {
        self.image = image
        self.model = model
        self.isLoaded = false
        self.unionAngle = model.unionState.rotationAngle
        self.unionPosition = model.unionState.normalizaCenter.cgValue
        self.unionFactor = 1.0
    }
    
    var body: some View {
        GeometryReader(content: { geometry in
            Image(image, scale: 1.0, label: Text(model.url.absoluteString))
                .opacity(isLoaded ? 1.0:0.0)
                .scaleEffect(unionFactor * image.size.cgValue.fitting(geometry.size))
                .rotationEffect(unionAngle)
                .position(unionPosition.applying(CGAffineTransform(scaleX: geometry.size.width, y: geometry.size.height)))
                .modifier(
                    ZoomViewModifiler(model: model, containerSize: geometry.size.size)
                )
                .modifier(
                    TwoTapsViewModifier(action: {
                        let nextState = model.state
                            .center(geometry.center.point)
                            .rotationAngle(.zero)
                            .factor(image.size.fitting(geometry.size.size))
                        model.state = nextState
                    })
                )
                .onChange(of: model.unionState, perform: { newValue in
                    let factor = newValue.factor / image.size.cgValue.fitting(geometry.size)
                    let center = newValue.center.cgValue.applying(CGAffineTransform(scaleX: 1 / geometry.size.width, y: 1 / geometry.size.height))
                    let updatePosition = unionPosition != center
                    let updateFactor = unionFactor != factor
                    let updateRotate = unionAngle != newValue.rotationAngle
                    
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
                            unionAngle = newValue.rotationAngle
                        }
                    }
                })
                .once {
                    let nextState = model.state
                        .center(geometry.center.point)
                        .rotationAngle(.zero)
                        .factor(image.size.fitting(geometry.size.size))
                        .originSize(image.size)
                    model.state = nextState
                    model.tempState = nextState
                    withAnimation(.smooth) {
                        isLoaded = true
                    }
                }
        })
    }
}
