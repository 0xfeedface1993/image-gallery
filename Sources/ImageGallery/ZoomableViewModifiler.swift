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
    
    @State private var scaleMode: ImageTransition = .init(mode: .scale(1.0, .zero)) {
        didSet {
            statePublisher.send((scaleMode, rotateMode))
        }
    }
    @State private var rotateMode: ImageTransition = .init(mode: .rotate(.zero, .zero)) {
        didSet {
            statePublisher.send((scaleMode, rotateMode))
        }
    }
    
    private let statePublisher = PassthroughSubject<(ImageTransition, ImageTransition), Never>()
    
    var containerSize: Size
    
    func body(content: Content) -> some View {
        content.gesture(
            pinchGesture()
                .simultaneously(with: rotationGesture())
        )
        .onReceive(
            statePublisher
                .removeDuplicates(by: { $0.0 == $1.0 && $0.1 == $1.1 })
                .receive(on: DispatchQueue.main)
        ) { (scale, rotate) in
            model.tempState = model.state.transform(scale, in: containerSize).transform(rotate, in: containerSize)
        }
    }

    private func rotationGesture() -> some Gesture {
        if #available(iOS 17.0, macOS 14.0, *) {
            return RotateGesture()
                .onChanged({ value in
                    if !model.isRotate {
                        model.isRotate = true
                    }
                    rotateMode = .init(mode: .rotate(value.rotation, value.startLocation.point))
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
                    rotateMode = .init(mode: .rotate(Angle(radians: value.radians), .zero))
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
                    scaleMode = .init(mode: .scale(value.magnification, value.startLocation.point))
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
                    scaleMode = .init(mode: .scale(value.magnitude, .zero))
                })
                .onEnded({ value in
                    model.state = model.tempState
                    model.isZooming = false
                })
        }
    }
}
