//
//  ZoomableViewModifiler.swift
//  S8Blocker
//
//  Created by Peter on 2024/6/20.
//

import SwiftUI
import Combine

fileprivate final class ZoomViewModel: ObservableObject {
    let scaleMode = PassthroughSubject<ImageTransition, Never>()
    let rotateMode = PassthroughSubject<ImageTransition, Never>()
    
    private var cancellable: AnyCancellable?
    
    deinit {
        cancellable?.cancel()
    }
    
    func bind(_ model: GallrayViewModel.Item, parameter: LayoutParameter) {
        cancellable?.cancel()
        let publisher = model.$state
        cancellable = scaleMode
            .combineLatest(rotateMode)
            .map { scale, rotate in
                (parameter.normalization(scale), parameter.normalization(rotate))
            }
            .sink(receiveValue: { [weak model] scale, rotate in
                guard let model else {
                    return
                }
                
                model.tempState = model.state
                    .transform(scale)
                    .transform(rotate)
            })
    }
}

struct ZoomViewModifiler: ViewModifier {
    @ObservedObject var model: GallrayViewModel.Item
    
    @StateObject private var viewModel = ZoomViewModel()
    
    var parameter: LayoutParameter
    
    init(model: GallrayViewModel.Item, parameter: LayoutParameter) {
        self.model = model
        self.parameter = parameter
    }
    
    func body(content: Content) -> some View {
        content.gesture(
            pinchGesture()
                .simultaneously(with: rotationGesture())
        )
        .once {
            viewModel.bind(model, parameter: parameter)
        }
    }

    private func rotationGesture() -> some Gesture {
        if #available(iOS 17.0, macOS 14.0, *) {
            return RotateGesture()
                .onChanged({ value in
                    if !model.isRotate {
                        model.isRotate = true
                    }
                    viewModel.rotateMode.send(.init(mode: .rotate(value.rotation, value.startLocation.point)))
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
                    viewModel.rotateMode.send(.init(mode: .rotate(Angle(radians: value.radians), .zero)))
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
                    viewModel.scaleMode.send(.init(mode: .scale(value.magnification, value.startLocation.point)))
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
                    viewModel.scaleMode.send(.init(mode: .scale(value.magnitude, .zero)))
                })
                .onEnded({ value in
                    model.state = model.tempState
                    model.isZooming = false
                })
        }
    }
}
