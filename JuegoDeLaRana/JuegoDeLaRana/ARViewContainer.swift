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
                
        // The arView is nullable and has to be built by the view model, if that hasn't completed yet. return a blank ARView that doesn't require AR
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
        
        /// Sends the tap gesture to the view model, which will pass the location of the tap to the ARView to check whether it is a valid surface, and spawn the table at that location in the 3D view
        @objc func handleTapGesture(_ gesture: UITapGestureRecognizer) {
            if gesture.state == .ended {
                let location = gesture.location(in: gesture.view)
                self.viewModel.handleTapGesture(location: location)
            }
        }
        
        //
        @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .ended {
                let location = gesture.location(in: gesture.view)
                let velocity = gesture.velocity(in: gesture.view)
                self.viewModel.handleFlickGesture(location: location, velocity: velocity)
            }
        }
        
        func setupCollisionHandling() {
            viewModel.entities.arView.scene.subscribe(to: CollisionEvents.Began.self) { event in
                self.viewModel.handleCollisions(for: event)
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
