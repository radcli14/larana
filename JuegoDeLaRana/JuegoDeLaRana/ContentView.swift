//
//  ContentView.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 8/27/24.
//

import SwiftUI
import RealityKit

struct ContentView : View {
    @ObservedObject var viewModel: LaRanaViewModel = LaRanaViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ARViewContainer()
                Header(for: geometry)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
            .overlay {
                OverlayView(
                    state: viewModel.state,
                    onTapReset: {
                        withAnimation {
                            viewModel.resetAnchor()
                        }
                    },
                    onTapMove: {
                        withAnimation {
                            viewModel.toggleMove()
                        }
                    },
                    onTapRotate: {
                        withAnimation {
                            viewModel.toggleRotate()
                        }
                    }
                )
            }
        }
        //EmptyView()
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
        
        arView.debugOptions = [.showFeaturePoints, .showWorldOrigin, .showAnchorOrigins, .showSceneUnderstanding, .showPhysics]

        // Create horizontal plane anchor for the content
        let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: SIMD2<Float>(Constants.anchorWidth, Constants.anchorWidth)))
        
        // Create a floor that sits with the anchor to visualize its location
        let mesh = MeshResource.generateBox(
            width: Constants.anchorWidth,
            height: Constants.anchorHeight,
            depth: Constants.anchorWidth,
            cornerRadius: 0.5 * Constants.anchorHeight
        )
        let material = SimpleMaterial(color: .green, roughness: 0.15, isMetallic: true)
        let floor = ModelEntity(mesh: mesh, materials: [material])
        floor.transform.translation.y = 0.5 * Constants.anchorHeight
        anchor.addChild(floor)
        
        // Load the La Rana scene
        if let larana = try? Entity.load(named: "TableAndLaRana.usdz") {
            // Append the loaded model to the anchor
            anchor.addChild(larana)

            // Add contact to the coin
            if let coin = larana.findEntity(named: "Coin") {
                // Set up the shape and physics for the coin
                coin.addPhysics(material: Materials.metal, mode: .dynamic)
                
                // TEMP: put the coin above the table so its visible and bounces a few times
                coin.position = SIMD3<Float>(0.1, 5.0, 0.0)
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    print("coin position = \(coin.position)")
                }
                
            } else {
                print("Coin entity not found.")
            }
            
            // Add contact to the turf sections
            let turfEntities = ["TableMainFront", "TableMainBack", "TableMainLeft", "TableMainRight"]
            addPhysics(to: turfEntities, in: larana, material: Materials.turf, mode: .static)
            
            // Add contact to La Rana
            let metalEntities = ["LaRanaFront", "LaRanaRear", "LaRanaLeft", "LaRanaRight"]
            addPhysics(to: metalEntities, in: larana, material: Materials.metal, mode: .static)
        }
        
        // Add the horizontal plane anchor to the scene
        arView.scene.anchors.append(anchor)

        return arView
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    // MARK: - Physics
    
    func addPhysics(to listOfEntityNames: [String], in mainEntity: Entity, material: PhysicsMaterialResource, mode: PhysicsBodyMode) {
        for name in listOfEntityNames {
            if let entity = mainEntity.findEntity(named: name) {
                entity.addPhysics(material: material, mode: mode)
            } else {
                print("Entity \(name) not found")
            }
        }
    }
    
    private struct Materials {
        static let metal = PhysicsMaterialResource.generate(friction: 0.3, restitution: 0.99)
        static let turf = PhysicsMaterialResource.generate(friction: 0.7, restitution: 0.5)
        static let wood = PhysicsMaterialResource.generate(friction: 0.5, restitution: 0.7)
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let anchorWidth: Float = 0.7
        static let anchorHeight: Float = 0.01
    }
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
                components.set(collisionComponent) // [CollisionComponent.self] = collisionComponent

                // Create and add a PhysicsBodyComponent
                let physicsBody = PhysicsBodyComponent(
                    massProperties: .default,
                    material: material,
                    mode: mode
                )
                components.set(physicsBody) //[PhysicsBodyComponent.self] = physicsBody
                
                print("Physics and collision components added to \(self)")
            }
        } else {
            print("No child with a ModelComponent found")
        }
    }
}

#Preview {
    ContentView()
    //ARViewContainer()
}
