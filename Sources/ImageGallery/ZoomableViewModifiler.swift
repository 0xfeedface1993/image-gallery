//
//  ZoomableViewModifiler.swift
//  S8Blocker
//
//  Created by Peter on 2024/6/20.
//

import SwiftUI
import Combine
import Core

enum CombineUpdate {
    case temp(NormalizedLayoutState)
    case all(temp: NormalizedLayoutState, state: NormalizedLayoutState)
    case none
}

struct ZoomViewModifiler: ViewModifier {
    @ObservedObject var model: GallrayViewModel.Item
    @Environment(\.galleryOptions) private var galleryOptions
    @Environment(\.events) private var events
    
    private let scaleMode = PassthroughSubject<UserAction, Never>()
    private let rotateMode = PassthroughSubject<UserAction, Never>()
    
    var parameter: LayoutParameter
    
    init(model: GallrayViewModel.Item, parameter: LayoutParameter) {
        self.model = model
        self.parameter = parameter
    }
    
    private var publisher: AnyPublisher<(UserAction, UserAction), Never> {
        scaleMode
            .combineLatest(rotateMode)
            .eraseToAnyPublisher()
    }
    
    func body(content: Content) -> some View {
        content.gesture(
            pinchGesture()
                .simultaneously(with: rotationGesture())
        )
        .onReceive(publisher, perform: { newValue in
            model.update(newValue.1, scaleAction: newValue.0, layoutOptions: galleryOptions)
            
            guard case let .scale(_, _, scaleState, _) = newValue.0,
                  case let .rotate(_, _, rotateState, _) = newValue.1 else {
                return
            }
            var states = [GestureEvent.StateChange]()
            states.append(
                .init(change: .scale(parameter.factor(model.state.factor)), state: scaleState)
            )
            states.append(
                .init(change: .rotate(model.state.rotationAngle), state: rotateState)
            )
            events(.gestures(.init(item: model.metadata, states: states)))
        })
    }
    
    private func rotationGesture() -> some Gesture {
        if #available(iOS 17.0, macOS 14.0, *) {
            return RotateGesture()
                .onChanged({ value in
                    onRotationnChange(parameter.normalization(value.startLocation.point), value: value.rotation)
                })
                .onEnded({ value in
                    onRotationnEnd(parameter.normalization(value.startLocation.point), value: value.rotation)
                })
        } else {
            // Fallback on earlier versions
            return RotationGesture()
                .onChanged({ value in
                    onRotationnChange(.center, value: value)
                })
                .onEnded({ value in
                    onRotationnEnd(.center, value: value)
                })
        }
    }
    
    private func pinchGesture() -> some Gesture {
        if #available(iOS 17.0, macOS 14.0, *) {
            return MagnifyGesture(minimumScaleDelta: 0.005)
                .onChanged({ value in
                    onMagnificationChange(parameter.normalization(value.startLocation.point), value: value.magnification)
                })
                .onEnded({ value in
                    onMagnificationEnd(parameter.normalization(value.startLocation.point), value: value.magnification)
                })
        } else {
            // Fallback on earlier versions
            return MagnificationGesture()
                .onChanged({ value in
                    onMagnificationChange(.center, value: value.magnitude)
                })
                .onEnded({ value in
                    onMagnificationEnd(.center, value: value.magnitude)
                })
        }
    }
    
    private func onMagnificationChange(_ startLocation: Point, value: Double) {
        guard galleryOptions.capability.contains(.scale) else {
            return
        }
        scaleMode.send(
            .scale(location: startLocation, magnification: value, state: .change, layoutOptions: galleryOptions)
        )
    }
    
    private func onMagnificationEnd(_ startLocation: Point, value: Double) {
        guard galleryOptions.capability.contains(.scale) else {
            return
        }
        scaleMode.send(
            .scale(location: startLocation, magnification: value, state: .end, layoutOptions: galleryOptions)
        )
    }
    
    private func onRotationnChange(_ startLocation: Point, value: Angle) {
        guard galleryOptions.capability.contains(.rotate) else {
            return
        }
        rotateMode.send(
            .rotate(location: startLocation, angle: value, state: .change, layoutOptions: galleryOptions)
        )
    }
    
    private func onRotationnEnd(_ startLocation: Point, value: Angle) {
        guard galleryOptions.capability.contains(.rotate) else {
            return
        }
        rotateMode.send(
            .rotate(location: startLocation, angle: value, state: .end, layoutOptions: galleryOptions)
        )
    }
}
