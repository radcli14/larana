//
//  ContentView.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 8/27/24.
//

import SwiftUI
import RealityKit

struct ContentView : View {
    var body: some View {
        ARViewContainer().edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = ARView(frame: .zero)

        // Create horizontal plane anchor for the content
        let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: SIMD2<Float>(0.2, 0.2)))

        // Load the La Rana scene
        if let larana = try? ModelEntity.loadModel(named: "Scene") {
            anchor.children.append(larana)
            if let laranaAnchor = larana.anchor {
                arView.scene.anchors.append(laranaAnchor)
            }
        }

        // Add the horizontal plane anchor to the scene
        arView.scene.anchors.append(anchor)

        return arView
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
}

#Preview {
    ContentView()
}
