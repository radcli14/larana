//
//  ARViewContainer.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 8/30/24.
//

import Foundation
import SwiftUI
import RealityKit
import Combine


struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: LaRanaViewModel
    
    func makeUIView(context: Context) -> ARView {
        
        // Add the tap gesture recognizer used for setting the table position
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTapGesture(_:)))
        viewModel.entities.arView.addGestureRecognizer(tapGesture)
        
        // Add the pan gesture recognizer used for flicking the coins
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePanGesture(_:)))
        viewModel.entities.arView.addGestureRecognizer(panGesture)
                
        return viewModel.entities.arView
        
    }
    
    // Coordinator class to manage cancellables
    class Coordinator {
        var viewModel: LaRanaViewModel
        var cancellables = Set<AnyCancellable>()
        
        init(viewModel: LaRanaViewModel) {
            self.viewModel = viewModel
            setupCollisionHandling()
        }
        
        @objc func handleTapGesture(_ gesture: UITapGestureRecognizer) {
            if gesture.state == .ended {
                let location = gesture.location(in: gesture.view)
                self.viewModel.handleTapGesture(location: location)
            }
        }
        
        @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .ended {
                let location = gesture.location(in: gesture.view)
                let velocity = gesture.velocity(in: gesture.view)
                self.viewModel.handleFlickGesture(location: location, velocity: velocity)
            }
        }
        
        func setupCollisionHandling() {
            viewModel.entities.arView.scene.subscribe(to: CollisionEvents.Began.self) { event in
                self.viewModel.handleCollisions(between: event.entityA.name, and: event.entityB.name)
            }.store(in: &cancellables)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(viewModel: viewModel)
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}

}

#Preview {
    ARViewContainer(viewModel: LaRanaViewModel())
}
