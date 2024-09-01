//
//  ARViewEntities.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 8/30/24.
//

import Foundation
import RealityKit

/// Provide a horizontal plane anchor for the content
private func getNewAnchor(for width: Float) -> AnchorEntity {
    AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: SIMD2<Float>(width, width)))
}

struct ARViewEntities {
    
    let arView = ARView(frame: .zero)
    
    var anchor: AnchorEntity
    var floor: ModelEntity?
    var larana: Entity?
    var coin: Entity?

    init() {
        anchor = getNewAnchor(for: Constants.anchorWidth)
        buildFloor()
        loadModel()
        
        // Add the horizontal plane anchor to the scene
        arView.scene.anchors.append(anchor)
        
        // Optional: set debug options
        //arView.debugOptions = [.showFeaturePoints, .showWorldOrigin, .showAnchorOrigins, .showSceneUnderstanding, .showPhysics]
    }
    
    // MARK: - Setup

    /// Create a floor that sits with the anchor to visualize its location
    mutating func buildFloor() {
        let mesh = MeshResource.generateBox(
            width: Constants.anchorWidth,
            height: Constants.anchorHeight,
            depth: Constants.anchorWidth,
            cornerRadius: 0.5 * Constants.anchorHeight
        )
        let material = SimpleMaterial(color: .gray.withAlphaComponent(0.5), roughness: 0.15, isMetallic: true)
        floor = ModelEntity(mesh: mesh, materials: [material])
        if let floor {
            floor.addPhysics(material: Materials.metal, mode: .static)
            //floor.transform.translation.y = 0.5 * Constants.anchorHeight
            anchor.addChild(floor)
        }
    }
    
    mutating func loadModel() {
        // Load the La Rana scene
        if let larana = try? Entity.load(named: "TableAndLaRana.usdz") {
            buildModel(for: larana)
        }
    }
    
    mutating func buildModel(for larana: Entity) {
        // Append the loaded model to the anchor (or floor if available, for drag to reposition)
        if let floor {
            floor.addChild(larana)
        } else {
            anchor.addChild(larana)
        }
        
        // Add physics to the coin and table contact surfaces
        buildCoin(in: larana)
        buildContactSurfaces(in: larana)

        // Update the reference to larana in this model so it gets published
        self.larana = larana
    }
    
    mutating func buildCoin(in larana: Entity) {
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
    }
    
    mutating func buildContactSurfaces(in larana: Entity) {
        // Add contact to the turf sections
        let turfEntities = ["TableMainFront", "TableMainBack", "TableMainLeft", "TableMainRight"]
        addPhysics(to: turfEntities, in: larana, material: Materials.turf, mode: .static)
        
        // Add contact to La Rana
        let metalEntities = ["LaRanaFront", "LaRanaRear", "LaRanaLeft", "LaRanaRight"]
        addPhysics(to: metalEntities, in: larana, material: Materials.metal, mode: .static)
    }
    
    // MARK: - Anchor
    
    mutating func resetAnchorLocation() {
        let newAnchor = getNewAnchor(for: Constants.anchorWidth)
        if let floor {
            floor.removeFromParent()
            floor.position = SIMD3<Float>(0.0, 0.0, 0.0)
            newAnchor.addChild(floor)
        }
        arView.scene.anchors.remove(anchor)
        arView.scene.anchors.append(newAnchor)
        anchor = newAnchor
    }
    
    // MARK: - Gestures
    
    var moveGestureRecognizers: [any EntityGestureRecognizer]?
    
    mutating func addMoveGesture() {
        if let floor {
            moveGestureRecognizers = arView.installGestures([.translation, .rotation], for: floor)
        }
    }
    
    mutating func removeMoveGesture() {
        moveGestureRecognizers?.forEach { recognizer in
            if let idx = arView.gestureRecognizers?.firstIndex(of: recognizer) {
                arView.gestureRecognizers?.remove(at: idx)
            }
        }
        moveGestureRecognizers = nil
    }
    
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
        static let anchorWidth: Float = 1.0
        static let anchorHeight: Float = 0.02
    }
}
