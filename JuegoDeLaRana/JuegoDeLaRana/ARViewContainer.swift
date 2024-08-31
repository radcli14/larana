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
        
        let arView = ARView(frame: .zero)
        
        //arView.debugOptions = [.showFeaturePoints, .showWorldOrigin, .showAnchorOrigins, .showSceneUnderstanding, .showPhysics]

        // Add the horizontal plane anchor to the scene
        arView.scene.anchors.append(viewModel.entities.anchor)

        if let floor = viewModel.entities.floor {
            arView.installGestures([.rotation, .translation], for: floor)
            print("Added gestures to the floor")
        }
        return arView
        
    }
    
    // Coordinator class to manage cancellables
    class Coordinator {
        var cancellables = Set<AnyCancellable>()
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}

}

#Preview {
    ARViewContainer(viewModel: LaRanaViewModel())
}
