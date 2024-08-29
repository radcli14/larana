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
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ARViewContainer()
                Header(for: geometry)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
            .overlay {
                OverlayView()
            }
        }
    }
    
    // MARK: - Header
    
    @ViewBuilder
    private func Header(for geometry: GeometryProxy) -> some View {
        Text("Juego de la Rana")
            .frame(maxWidth: Constants.maxHeaderWidth)
            .font(.custom(Constants.headerFontName, size: headerFontSize))
            .padding(.top, topPadding(for: geometry.safeAreaInsets.top))
            .padding(.bottom, Constants.headerBottomPadding)
            .background {
                RoundedRectangle(cornerRadius: Constants.backgroundCornerRadius)
                    .foregroundColor(.accentColor)
                    .shadow(radius: Constants.headerShadowRadius)
            }
    }
    
    private func topPadding(for inset: CGFloat) -> CGFloat {
        inset > Constants.headerBottomPadding ? inset : Constants.headerBottomPadding
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let maxHeaderWidth: CGFloat = 420
        static let headerFontName = "Moderna"
        static let headerTopPadding: CGFloat = 56
        static let headerBottomPadding: CGFloat = 12
        static let backgroundCornerRadius: CGFloat = 56
        static let headerShadowRadius: CGFloat = 16
    }
    
    private var headerFontSize: CGFloat {
        UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
    }
}

struct ARViewContainer: UIViewRepresentable {
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = ARView(frame: .zero)
        
        arView.debugOptions = [.showFeaturePoints, .showWorldOrigin]

        // Create horizontal plane anchor for the content
        let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: SIMD2<Float>(0.2, 0.2)))

        // Load the La Rana scene
        if let larana = try? Entity.load(named: "Scene.usdz") {
            // Append the loaded model to the anchor
            anchor.addChild(larana)

            // Search for the "Coin" entity within the loaded scene
            if let coin = larana.findEntity(named: "Coin") {
                print("Coin entity found: \(coin) \(coin.position) \(coin.components)")
                
                // TEMP: put the coin above the table so its visible
                coin.position = SIMD3<Float>(0.0, 1.0, 0.0)
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    print("coin position = \(coin.position)")
                }
                
                let shape = ShapeResource.generateCapsule(height: 0.005, radius: 0.015)
                let physicsBody = PhysicsBodyComponent(
                    shapes: [shape],
                    mass: 0.1,
                    mode: .dynamic
                )
                coin.components[PhysicsBodyComponent.self] = physicsBody
                coin.components[CollisionComponent.self] = CollisionComponent(shapes: [shape])
            } else {
                print("Coin entity not found.")
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
