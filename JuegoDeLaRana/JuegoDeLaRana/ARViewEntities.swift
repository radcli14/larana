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
    var coins = [Entity]()

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
        let mesh = MeshResource.generatePlane(width: Constants.anchorWidth, depth: Constants.anchorWidth)
        let material = SimpleMaterial(color: .gray.withAlphaComponent(0.5), roughness: 0.15, isMetallic: true)
        floor = ModelEntity(mesh: mesh, materials: [material])
        if let floor {
            floor.addPhysics(material: Materials.wood, mode: .static)
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
        let name = "coin"
        if let coin = larana.findEntity(named: name) {
            self.coin = coin
            coin.position = SIMD3<Float>(0, 0, 0)
        } else {
            print("\(name) entity not found.")
        }
    }
    
    mutating func buildContactSurfaces(in larana: Entity) {
        // Add contact to the turf sections
        let turfEntities = ["TableMainTurf_Cube_017", "TableBackTurf_Cube_016", "TableWallLeftTurf_Cube_018", "TableWallRightTurf_Cube_019"]
        addPhysics(to: turfEntities, in: larana, material: Materials.turf, mode: .static)
        
        // Add contact to La Rana
        let metalEntities = ["Mesh"]
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
    
    mutating func tossCoin(with velocity: SIMD3<Float>) {
        // We get the current anchor here to ensure if there was a dynamic update, the correct anchor is parented
        guard let currentAnchor = arView.scene.anchors.first else {
            print("tossCoin couldn't get current anchor")
            return
        }
        
        // As long as the model has been loaded, we should be able to generate a fresh coin
        guard let generatedCoin = coin?.clone(recursive: true) else {
            print("tossCoin couldn't generate a new coin")
            return
        }
        
        // Use these to get the position of the camera relative to the anchor, and orientation in world frame
        let cameraTransform = arView.cameraTransform
        let cameraTransformFromAnchor = getCameraTransformRelativeTo(entity: currentAnchor)

        // Set the position of the fresh coin to slightly in front of and below the device prior to toss
        generatedCoin.position = cameraTransformFromAnchor.translation
        generatedCoin.position.y -= 0.2
        generatedCoin.position.z -= 0.2
        
        // The flick velocity will set the velocity relative to the camera, but we need to rotate it into world frame
        let velocityInWorldFrame = cameraTransform.matrix * SIMD4<Float>(velocity.x, velocity.y, velocity.z, 0.0)
        
        // Set a new PhysicsMotionComponent to add initial velocity, and randomize angular velocity
        generatedCoin.components.set(PhysicsMotionComponent(
            linearVelocity: SIMD3<Float>(velocityInWorldFrame.x, velocityInWorldFrame.y, velocityInWorldFrame.z),
            angularVelocity: SIMD3<Float>(Float.random(in: -5...5), Float.random(in: -5...5), Float.random(in: -5...5))
        ))
        
        // Add contact to the coin
        generatedCoin.addPhysics(material: Materials.metal, mode: .dynamic)
        
        // Set the parent to the anchor
        generatedCoin.setParent(currentAnchor)
        
        // DEBUG
        print("tossing coin \(generatedCoin) at position \(generatedCoin.position) with velocity \(velocity)")
        print("anchors count = \(arView.scene.anchors.count)")
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false, block: { _ in
            print("1 second later for coin \(generatedCoin.name) at position \(generatedCoin.position) with velocity \(velocity)")
        })
    }
    
    func getCameraTransformRelativeTo(entity: Entity) -> Transform {
        let cameraTransform = arView.cameraTransform
        let entityTransform = entity.transformMatrix(relativeTo: nil)
        let invertedEntityTransform = entityTransform.inverse
        let relativeTransformMatrix = invertedEntityTransform * cameraTransform.matrix
        return Transform(matrix: relativeTransformMatrix)
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
        static let metal = PhysicsMaterialResource.generate(friction: 0.3, restitution: 0.9)
        static let turf = PhysicsMaterialResource.generate(friction: 0.8, restitution: 0.2)
        static let wood = PhysicsMaterialResource.generate(friction: 0.5, restitution: 0.7)
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let anchorWidth: Float = 0.7
        static let anchorHeight: Float = 0.02
    }
}
