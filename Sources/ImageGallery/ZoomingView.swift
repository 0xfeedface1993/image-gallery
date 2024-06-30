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
    
    @State private var tempState: ImageLayoutState
    @State private var isRotate = false
    @State private var isDrag = false
    @State private var isZooming = false
    @State private var isLoaded = false
    @Environment(\.imageTargetTransformer) private var imageTargetTransformer
    
    init(image: CGImage, model: GallrayViewModel.Item) {
        self.image = image
        self.tempState = model.state
        self.model = model
    }
    
    var body: some View {
        GeometryReader(content: { geometry in
            Image(image, scale: 1.0, label: Text(model.url.absoluteString))
                .scaleEffect(isZooming ? tempState.factor:model.state.factor)
                .rotationEffect(isRotate ? tempState.rotationAngle:model.state.rotationAngle)
                .position(isDrag || isZooming ? tempState.center.cgValue:model.state.center.cgValue)
                .modifier(
                    DragViewModifiler(base: $model.state, dynamic: $tempState, isDrag: $isDrag, containerSize: geometry.size.size)
                )
                .modifier(
                    ZoomViewModifiler(base: $model.state, dynamic: $tempState, isRotate: $isRotate, isZooming: $isZooming, containerSize: geometry.size.size)
                )
                .modifier(
                    TwoTapsViewModifier(action: {
                        let nextState = model.state
                            .center(geometry.center.point)
                            .rotationAngle(.zero)
                            .factor(image.size.fitting(geometry.size.size))
                        model.state = nextState
                        tempState = nextState
                    })
                )
                .opacity(isLoaded ? 1.0:0.0)
                .once {
                    let nextState = model.state
                        .center(geometry.center.point)
                        .rotationAngle(.zero)
                        .factor(image.size.fitting(geometry.size.size))
                    model.state = nextState
                    tempState = nextState
                    withAnimation {
                        isLoaded = true
                    }
                }
        })
    }
}
