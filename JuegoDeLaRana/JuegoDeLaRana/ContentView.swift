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
        
        //arView.debugOptions = [.showFeaturePoints, .showWorldOrigin, .showAnchorOrigins, .showSceneUnderstanding, .showPhysics]

        // Create horizontal plane anchor for the content
        let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: SIMD2<Float>(0.2, 0.2)))

        // Load the La Rana scene
        if let larana = try? Entity.load(named: "TableAndLaRana.usdz") {
            // Append the loaded model to the anchor
            anchor.addChild(larana)

            let metal = PhysicsMaterialResource.generate(friction: 0.3, restitution: 0.99)
            let turf = PhysicsMaterialResource.generate(friction: 0.7, restitution: 0.5)
            let wood = PhysicsMaterialResource.generate(friction: 0.5, restitution: 0.7)
            
            // Search for the "Coin" entity within the loaded scene
            if let coin = larana.findEntity(named: "Coin") {
                print("Coin entity found: \(coin) \(coin.position) \(coin.components)")
                
                // TEMP: put the coin above the table so its visible
                coin.position = SIMD3<Float>(0.1, 5.0, 0.0)
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    print("coin position = \(coin.position)")
                }
                
                // Set up the shape and physics for the coin
                coin.addPhysics(material: metal, mode: .dynamic)
                
            } else {
                print("Coin entity not found.")
            }
            
            // Add contact to the turf sections
            let turfEntities = ["TableMainFront", "TableMainBack", "TableMainLeft", "TableMainRight"]
            for name in turfEntities  {
                if let table = larana.findEntity(named: name) {
                    table.addPhysics(material: turf, mode: .static)
                } else {
                    print("Table entity \(name) not found")
                }
            }
            
            // Add contact to La Rana
            let metalEntities = ["LaRanaFront", "LaRanaRear", "LaRanaLeft", "LaRanaRight"]
            for name in metalEntities  {
                if let frog = larana.findEntity(named: name) {
                    frog.addPhysics(material: metal, mode: .static)
                } else {
                    print("Frog entity \(name) not found")
                }
            }
        }
        
        // Add the horizontal plane anchor to the scene
        arView.scene.anchors.append(anchor)

        return arView
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

extension Entity {
    func addPhysics(material: PhysicsMaterialResource, mode: PhysicsBodyMode) {
        if let childWithModel = children.first(
            where: { $0.components[ModelComponent.self] != nil }
        ) {
            if let modelComponent = childWithModel.components[ModelComponent.self] as? ModelComponent {
                
                // Generate collision shapes based on the model's mesh
                let shape = ShapeResource.generateConvex(from: modelComponent.mesh)
                let collisionComponent = CollisionComponent(shapes: [shape])
                components[CollisionComponent.self] = collisionComponent

                // Create and add a PhysicsBodyComponent
                let physicsBody = PhysicsBodyComponent(
                    massProperties: .default,
                    material: material,
                    mode: mode
                )
                components[PhysicsBodyComponent.self] = physicsBody
                
                print("Physics and collision components added to \(self)")
            }
        } else {
            print("No child with a ModelComponent found")
        }
    }
}

#Preview {
    ContentView()
}
