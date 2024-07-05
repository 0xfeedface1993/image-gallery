//
//  ZoomableViewModifiler.swift
//  S8Blocker
//
//  Created by Peter on 2024/6/20.
//

import SwiftUI
import Combine

struct ZoomViewModifiler: ViewModifier {
    @ObservedObject var model: GallrayViewModel.Item
    
    private let scaleMode = PassthroughSubject<ImageTransition, Never>()
    private let rotateMode = PassthroughSubject<ImageTransition, Never>()
    
    var parameter: LayoutParameter
    
    init(model: GallrayViewModel.Item, parameter: LayoutParameter) {
        self.model = model
        self.parameter = parameter
    }
    
    private var publisher: AnyPublisher<NormalizationLayoutState, Never> {
        scaleMode
            .combineLatest(rotateMode)
            .map { scale, rotate in
                (parameter.normalization(scale), parameter.normalization(rotate))
            }
            .map({ scale, rotate in
                model.state
                    .transform(scale)
                    .transform(rotate)
            })
            .eraseToAnyPublisher()
    }
    
    func body(content: Content) -> some View {
        content.gesture(
            pinchGesture()
                .simultaneously(with: rotationGesture())
        )
        .onReceive(publisher, perform: { newValue in
            model.tempState = newValue
        })
    }

    private func rotationGesture() -> some Gesture {
        if #available(iOS 17.0, macOS 14.0, *) {
            return RotateGesture()
                .onChanged({ value in
                    if !model.isRotate {
                        model.isRotate = true
                    }
                    rotateMode.send(.init(mode: .rotate(value.rotation, value.startLocation.point)))
                })
                .onEnded({ value in
                    let next = model.tempState
                    model.state = next
                    model.isRotate = false
                })
        } else {
            // Fallback on earlier versions
            return RotationGesture()
                .onChanged({ value in
                    if !model.isRotate {
                        model.isRotate = true
                    }
                    rotateMode.send(.init(mode: .rotate(Angle(radians: value.radians), .zero)))
                })
                .onEnded({ value in
                    let next = model.tempState
                    model.state = next
                    model.isRotate = false
                })
        }
    }
    
    private func pinchGesture() -> some Gesture {
        if #available(iOS 17.0, macOS 14.0, *) {
            return MagnifyGesture(minimumScaleDelta: 0.005)
                .onChanged({ value in
                    if !model.isZooming {
                        model.isZooming = true
                    }
                    scaleMode.send(.init(mode: .scale(value.magnification, value.startLocation.point)))
                })
                .onEnded({ value in
                    model.state = model.tempState
                    model.isZooming = false
                })
        } else {
            // Fallback on earlier versions
            return MagnificationGesture()
                .onChanged({ value in
                    if !model.isZooming {
                        model.isZooming = true
                    }
                    scaleMode.send(.init(mode: .scale(value.magnitude, .zero)))
                })
                .onEnded({ value in
                    model.state = model.tempState
                    model.isZooming = false
                })
        }
    }
}
