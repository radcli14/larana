//
//  ARViewEntities.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 8/30/24.
//

import Foundation
import ARKit
import RealityKit

/// Provide a horizontal plane anchor for the content
private func getNewAnchor(for width: Float) -> AnchorEntity {
    AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: SIMD2<Float>(width, width)))
}

class ARViewEntities: NSObject, ARSessionDelegate {
    
    let arView = ARView(frame: .zero)
    
    // Entities
    var anchor: AnchorEntity?
    var floor: ModelEntity?
    var larana: Entity?
    var coin: Entity?
    var coins = [Entity]()
    
    // Collisions
    let tableGroup = CollisionGroup(rawValue: 1 << 0)
    let coinGroup = CollisionGroup(rawValue: 1 << 1)
    let generalGroup = CollisionGroup(rawValue: 1 << 2)

    override init() {
        super.init()

        anchor = getNewAnchor(for: Constants.anchorWidth)
        buildFloor()
        loadModel()
        addPointLight()
        
        // Add the horizontal plane anchor to the scene
        if let anchor {
            arView.scene.anchors.append(anchor)
        }
        
        addPlaneDetection()
        
        // Optional: set debug options
        //arView.debugOptions = [.showFeaturePoints, .showWorldOrigin, .showAnchorOrigins, .showSceneUnderstanding, .showPhysics]
    }
    
    // MARK: - Setup
    
    /// Create a floor that sits with the anchor to visualize its location
    func buildFloor() {
        let mesh = MeshResource.generatePlane(width: Constants.anchorWidth, depth: Constants.anchorWidth)
        let material = SimpleMaterial(color: .gray.withAlphaComponent(0.0), roughness: 0.15, isMetallic: true)
        floor = ModelEntity(mesh: mesh, materials: [material])
        if let floor, let anchor {
            floor.addPhysics(material: Materials.wood, mode: .static)
            floor.position = SIMD3<Float>(0, 0.01, 0)
            anchor.addChild(floor)
        }
    }

    func loadModel() {
        // Load the La Rana scene
        if let larana = try? Entity.load(named: "TableAndLaRana.usdz") {
            buildModel(for: larana)
        }
    }
    
    func buildModel(for larana: Entity) {
        // Append the loaded model to the anchor (or floor if available, for drag to reposition)
        if let floor {
            floor.addChild(larana)
        } else if let anchor {
            anchor.addChild(larana)
        }
        
        // Add physics to the coin and table contact surfaces
        buildCoin(in: larana)
        buildContactSurfaces(in: larana)

        // Update the reference to larana in this model so it gets published
        self.larana = larana
    }
    
    func buildCoin(in larana: Entity) {
        if let coin = larana.findEntity(named: Constants.coinName) {
            self.coin = coin
            coin.position = SIMD3<Float>(0, 0, 0)
        } else {
            print("\(Constants.coinName) entity not found.")
        }
    }
    
    func buildContactSurfaces(in larana: Entity) {
        // Add contact to the turf sections
        let turfEntities = ["TableMainTurf_Cube_017", "TableBackTurf_Cube_016", "TableWallLeftTurf_Cube_018", "TableWallRightTurf_Cube_019",
                            "target"] // Include the target, want a dull bounce (if any) when the coin hits it
        addPhysics(to: turfEntities, in: larana, material: Materials.turf, mode: .static, collisionGroup: tableGroup)
        
        // Add contact to La Rana
        let metalEntities = ["Mesh"]
        addPhysics(to: metalEntities, in: larana, material: Materials.metal, mode: .static, collisionGroup: tableGroup)

        // Add contact to the wood frame
        let woodEntities: [String] = [
            "ChuteFront_Cube_011", "ChuteSlope_Cube_012", "ChuteRight_Cube_013", "ChuteLeft_Cube_014",
            "LegFrontRight_Cube", "LegFrontLeft_Cube_001", "LegRearRight_Cube_002", "LegRearLeft_Cube_003",
            "SupportLowerFront_Cube_008", "SupportLowerRear_Cube_009", "SupportLowerCenter_Cube_010"
        ]
        addPhysics(to: woodEntities, in: larana, material: Materials.wood, mode: .static)
    }
    
    func addPointLight() {
        // Create a Point Light in front of La Rana
        let lightEntity = Entity()
        lightEntity.components.set(PointLightComponent(
            color: .white,
            intensity: 1000,
            attenuationRadius: 0.5
        ))
        lightEntity.position = SIMD3<Float>(0, 0.8, 0.3)
        lightEntity.setParent(floor ?? anchor)
    }
    
    // MARK: - Anchor
    
    func resetAnchorLocation() {
        let newAnchor = getNewAnchor(for: Constants.anchorWidth)
        if let floor {
            floor.removeFromParent()
            floor.position = SIMD3<Float>(0.0, 0.0, 0.0)
            newAnchor.addChild(floor)
        }
        if let anchor {
            arView.scene.anchors.remove(anchor)
        }
        arView.scene.anchors.append(newAnchor)
        anchor = newAnchor
    }
    
    // MARK: - Gestures
    
    var moveGestureRecognizers: [any EntityGestureRecognizer]?
    
    func addMoveGesture() {
        if let floor {
            moveGestureRecognizers = arView.installGestures([.translation, .rotation], for: floor)
        }
    }
    
    func removeMoveGesture() {
        moveGestureRecognizers?.forEach { recognizer in
            if let idx = arView.gestureRecognizers?.firstIndex(of: recognizer) {
                arView.gestureRecognizers?.remove(at: idx)
            }
        }
        moveGestureRecognizers = nil
    }
    
    private var randomAngularRate: Float {
        Float.random(in: Constants.angularRateRange)
    }
    
    func tossCoin(with velocity: SIMD3<Float>, index: Int? = nil) {
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
        
        // Name the coin based on its index
        if let index {
            generatedCoin.name = "coin\(index)"
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
            angularVelocity: SIMD3<Float>(randomAngularRate, randomAngularRate, randomAngularRate)
        ))
        
        // Add contact to the coin
        generatedCoin.addPhysics(material: Materials.metal, mode: .dynamic)
        
        // Set the parent to the anchor so that it exists in the scene
        generatedCoin.setParent(currentAnchor)
        
        // Add to the array of coins, for clearing in the future
        coins.append(generatedCoin)
    }
    
    func addFilterAfterHitTarget(to name: String) {
        guard let currentAnchor = arView.scene.anchors.first else {
            print("addFilterAfterHitTarget couldn't get current anchor")
            return
        }

        if let coin = currentAnchor.findEntity(named: name) {
            addCollisionFilter(to: coin, group: coinGroup, mask: .all.subtracting(tableGroup))
            reduceVelocity(of: coin, anchor: currentAnchor)
        }
    }
    
    func getCameraTransformRelativeTo(entity: Entity) -> Transform {
        let cameraTransform = arView.cameraTransform
        let entityTransform = entity.transformMatrix(relativeTo: nil)
        let invertedEntityTransform = entityTransform.inverse
        let relativeTransformMatrix = invertedEntityTransform * cameraTransform.matrix
        return Transform(matrix: relativeTransformMatrix)
    }
    
    // MARK: - Physics
    
    func addPhysics(
        to listOfEntityNames: [String],
        in mainEntity: Entity,
        material: PhysicsMaterialResource,
        mode: PhysicsBodyMode,
        collisionGroup: CollisionGroup? = nil,
        collisionMask: CollisionGroup? = nil
    ) {
        for name in listOfEntityNames {
            if let entity = mainEntity.findEntity(named: name) {
                entity.addPhysics(material: material, mode: mode)
                addCollisionFilter(to: entity, group: collisionGroup ?? generalGroup, mask: collisionMask ?? .all)
            } else {
                print("Entity \(name) not found")
            }
        }
    }
    
    func addCollisionFilter(to entity: Entity, group: CollisionGroup = .all, mask: CollisionGroup = .all) {
        if var collision = entity.components[CollisionComponent.self] as? CollisionComponent {
            collision.filter = CollisionFilter(group: group, mask: mask)
            entity.components[CollisionComponent.self] = collision
            print("Collision filter \(collision.filter) added to \(entity.name)")
        }
    }
    
    /// Reduce the coin velocity to make it more likely to drop into the chute after hitting the target
    private func reduceVelocity(of coin: Entity, anchor: Entity) {
        DispatchQueue.main.async {
            anchor.removeChild(coin)
            if let motion = coin.components[PhysicsMotionComponent.self] as? PhysicsMotionComponent {
                coin.components.remove(PhysicsMotionComponent.self)
                coin.components.set(PhysicsMotionComponent(
                    linearVelocity: 0.25 * motion.linearVelocity,
                    angularVelocity: motion.angularVelocity
                ))
                print("After hitting the target, set coin velocity to \(motion.linearVelocity)")
            }
            anchor.addChild(coin)
        }
    }
    
    private struct Materials {
        static let metal = PhysicsMaterialResource.generate(friction: 0.3, restitution: 0.9)
        static let turf = PhysicsMaterialResource.generate(friction: 0.8, restitution: 0.2)
        static let wood = PhysicsMaterialResource.generate(friction: 0.5, restitution: 0.7)
    }
    
    // MARK: Plane Detection
    
    func addPlaneDetection() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        arView.session.delegate = self
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func addPlaneAnchor(_ anchor: ARPlaneAnchor) {
        // This is a new plane, give it a mesh and add contact physics
        let plane = ModelEntity(mesh: .generatePlane(width: anchor.planeExtent.width, depth: anchor.planeExtent.height), materials: [SimpleMaterial(color: .white.withAlphaComponent(0.0), roughness: 1, isMetallic: false)])
        let anchorEntity = AnchorEntity(world: anchor.transform)
        anchorEntity.name = anchor.identifier.uuidString
        anchorEntity.addChild(plane)
        plane.addPhysics(material: Materials.wood, mode: .static)
        arView.scene.addAnchor(anchorEntity)
    }
    
    func updatePlaneAnchor(_ anchor: ARPlaneAnchor) {
        // This plane already existed, update it with new dimensions
        if let anchorEntity = arView.scene.findEntity(named: anchor.identifier.uuidString) {
            if let plane = anchorEntity.children.first as? ModelEntity {
                // Update the transform (position and rotation) of the anchor entity
                anchorEntity.position = SIMD3<Float>(anchor.center.x, 0, anchor.center.z)
                let anchorRotation = simd_quatf(anchor.transform)
                anchorEntity.orientation = anchorRotation
              
                // Update the plane's mesh to match the new dimensions
                plane.model = ModelComponent(
                    mesh: .generatePlane(width: anchor.planeExtent.width, depth: anchor.planeExtent.height),
                    materials: [SimpleMaterial(color: .white.withAlphaComponent(0.0), roughness: 1, isMetallic: false)]
                )
            }
        }
    }
    
    // MARK: - ARSessionDelegate Methods

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Handle newly added anchors
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                addPlaneAnchor(planeAnchor)
            }
        }
    }

    var lastAnchorUpdate: Date?

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Handle updated anchors
        let now = Date()
        if let lastUpdate = lastAnchorUpdate, now.timeIntervalSince(lastUpdate) < 1.0 {
            return // Throttle updates to once per second
        }
        self.lastAnchorUpdate = now
        
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                updatePlaneAnchor(planeAnchor)
            }
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            // Remove the corresponding entity from the scene
            if let planeAnchor = anchor as? ARPlaneAnchor,
               let entity = arView.scene.findEntity(named: planeAnchor.identifier.uuidString) {
                entity.removeFromParent()
            }
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        // Handle session errors
        print("AR Session failed with error: \(error)")
    }

    func sessionWasInterrupted(_ session: ARSession) {
        // Handle session interruption
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        // Handle end of session interruption
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let anchorWidth: Float = 0.7
        static let anchorHeight: Float = 0.02
        static let coinName = "coin"
        static let angularRateRange = Float(-50)...Float(50)
    }
}
