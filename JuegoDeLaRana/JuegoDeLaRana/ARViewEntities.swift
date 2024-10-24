//
//  ARViewEntities.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 8/30/24.
//

import Foundation
import ARKit
import RealityKit
import CoreMotion
import Combine

/// Provide a horizontal plane anchor for the content
private func getNewAnchor(for width: Float) -> AnchorEntity {
    return AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: SIMD2<Float>(width, width)))
}

class ARViewEntities: NSObject, ARSessionDelegate {
    
    var arView: ARView
    
    var audioResources: AudioResources?
    
    let motionManager = CMMotionManager()

    // Entities
    var triangulo: Entity?
    var vrCameraAnchor: AnchorEntity?
    var anchor: AnchorEntity?
    var floor: ModelEntity?
    var occluder: ModelEntity?
    var larana: Entity?
    var coin: Entity?
    var coins = [Entity]()
    
    var fireworkEmitter: Entity?
    
    var target: Entity? {
        anchor?.findEntity(named: "target")
    }
    
    var hole: Entity? {
        anchor?.findEntity(named: "TableHole_Cylinder")
    }
    
    // Collisions
    let tableGroup = CollisionGroup(rawValue: 1 << 0)
    let coinGroup = CollisionGroup(rawValue: 1 << 1)
    let generalGroup = CollisionGroup(rawValue: 1 << 2)
    
    init(cameraMode: ARView.CameraMode = .nonAR) {
        arView = ARView(frame: .zero, cameraMode: cameraMode, automaticallyConfigureSession: true)
        arView.environment.lighting.resource = nil
        super.init()

        // Optional: set debug options
        //arView?.debugOptions = [.showFeaturePoints, .showWorldOrigin, .showAnchorOrigins, .showSceneUnderstanding, .showPhysics]
    }
    
    // MARK: - AR View Modes
    
    private let sceneUnderstandingOptions: [ARView.Environment.SceneUnderstanding.Options] = [
        .receivesLighting, .occlusion, .physics
    ]
    
    /// Adds Scene Understanding to the `arView`, so that the coins bounce off the ground, tables occlude the model, etc
    func addSceneUnderstanding() {
        for option in sceneUnderstandingOptions {
            arView.environment.sceneUnderstanding.options.insert(option)
        }
    }
    
    /// Removes Scene Understanding from the `arView`
    func removeSceneUnderstanding() {
        for option in sceneUnderstandingOptions {
            arView.environment.sceneUnderstanding.options.remove(option)
        }
    }
    
    /// Toggle between VR (no camera) and AR (with camera) mode
    func toggleArCameraMode(to cameraMode: ARView.CameraMode) {
        let modeBefore = arView.cameraMode
        stopFireworks()
        if modeBefore == .nonAR && cameraMode == .ar {
            deactivateVrScene()
        } else if modeBefore == .ar && cameraMode == .nonAR {
            activateVrScene()
        }
    }
    
    /// Activates the VR (no camera) scene, and removes the AR scene
    func activateVrScene() {
        guard let triangulo else {
            print("Failed to activate the VR scene because triangulo was nil")
            return
        }
        
        removeSceneUnderstanding()
        arView.scene.anchors.removeAll()
        anchor = nil
        
        let nonArAnchor = AnchorEntity(world: SIMD3<Float>())
        setAnchor(to: nonArAnchor)
        triangulo.setParent(nonArAnchor)
        
        let cameraEntity = PerspectiveCamera()
        cameraEntity.camera.fieldOfViewInDegrees = 60
        var cameraTransform = Transform(pitch: -0.4)
        cameraTransform.translation = SIMD3<Float>(0, 1.75, 4)
        vrCameraAnchor = AnchorEntity(world: cameraTransform.matrix)
        vrCameraAnchor?.addChild(cameraEntity)
        startTrackingDeviceMotion()
        arView.scene.addAnchor(vrCameraAnchor!)
        
        let vrFadeOutTime = 2.0
        let startTime = Date.now
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            let t = Date.now.timeIntervalSince(startTime)
            if #available(iOS 18.0, *) {
                if let _ = self.triangulo?.components[OpacityComponent.self]?.opacity {
                    self.triangulo?.components[OpacityComponent.self]?.opacity = Float(1 - 0.5 * cos(.pi*t/vrFadeOutTime))
                }
            }
            if t >= vrFadeOutTime {
                timer.invalidate()
                if #available(iOS 18.0, *) {
                    self.triangulo?.components[OpacityComponent.self]?.opacity = 1
                }
                self.arView.cameraMode = .nonAR
            }
        }
    }
    
    /// Deactivates the VR (no camera) scene and adds the AR (with camera) scene
    func deactivateVrScene() {
        hideTable()
        self.arView.cameraMode = .ar
        addSceneUnderstanding()
        let vrFadeOutTime = 2.0
        let startTime = Date.now
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            let t = Date.now.timeIntervalSince(startTime)
            if #available(iOS 18.0, *) {
                self.triangulo?.components[OpacityComponent.self]?.opacity = Float(0.5 + 0.5 * cos(.pi*t/vrFadeOutTime))
            }
            if t >= vrFadeOutTime {
                self.triangulo?.removeFromParent()
                //self.vrCameraAnchor?.removeFromParent()
                self.arView.scene.anchors.removeAll()
                self.anchor = nil
                timer.invalidate()
                print("removed triangulo")
            }
        }
    }
    
    func startTrackingDeviceMotion() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60 Hz refresh rate
            motionManager.startDeviceMotionUpdates(to: .main) { (motion, error) in
                if let motion = motion {
                    self.updateVirtualCameraTransform(with: motion)
                }
            }
        }
    }
    
    // MARK: - Virtual Camera
    
    private var orientation: UIDeviceOrientation {
        UIDevice.current.orientation
    }
    
    /// Stores the last device attitude in case we want to use that to update the virtual camera
    private var attitude: CMAttitude?
    
    /// Stores a quaternion intended to use to assure the camera is centered on the table in the VR view
    private var virtualCameraAdjustmentQuaternion = simd_quatf(ix: 0, iy: 0, iz: 0,  r: 1)
    
    /// Animates the `virtualCameraAdjustmentQuaternion` so that the camera is pointed at the table in the VR view
    func updateVirtualCameraAdjustmentQuaternion(duration: Double = 0.5) {
        print("updateVirtualCameraAdjustmentQuaternion")
        guard let targetRotation = correctedCoreMotionQuaternion?.inverse else {
            print("Failed getting device attitude in updateVirtualCameraAdjustmentQuaternion")
            return
        }
        
        let startRotation = virtualCameraAdjustmentQuaternion
        
        var cancellable: Cancellable?
        let startTime = Date()

        cancellable = vrCameraAnchor?.scene?.subscribe(to: SceneEvents.Update.self, { event in
            let elapsedTime = Date().timeIntervalSince(startTime)
            let t = min(elapsedTime / duration, 1.0)
            let progress = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t // easeInOut equation

            // Spherically interpolate between start and target rotation
            self.virtualCameraAdjustmentQuaternion = simd_slerp(startRotation, targetRotation, Float(progress))

            if progress >= 1.0 {
                cancellable?.cancel()
            }
        })
    }
    
    /// Provides a quaternion associated with the instantaneous device orientation, with rotation for landscape vs portrait modes
    private var coreMotionQuaternion: simd_quatf? {
        // Get the device attitude quaternion and orientation (landscape vs portrait) at this instant
        guard let attitude else {
            print("Failed getting device attitude in updateVirtualCameraTransform")
            return nil
        }
        
        // When the device is in landscape mode, the horizontal "x" axis is actually the device's "negative-y" axis.
        // Make these adjustments here using the ternary operator in the creation of ix and iy
        let r = Float(attitude.quaternion.w)
        let ix = Float(orientation.isLandscape ? -attitude.quaternion.y : attitude.quaternion.x)
        let iy = Float(orientation.isLandscape ? attitude.quaternion.x : attitude.quaternion.y)
        let iz = Float(attitude.quaternion.z)
        return simd_quatf(ix: ix, iy: iy, iz: iz,  r: r)
    }
    
    /// Correction quaternion to adjust for the coordinate system difference between CoreMotion and RealityKit
    private var correctionQuaternion: simd_quatf {
        var correctionQuaternion = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        if orientation.isLandscape {
            correctionQuaternion *= simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(0, 0, 1))
        }
        return correctionQuaternion
    }
    
    private var correctedCoreMotionQuaternion: simd_quatf? {
        guard let coreMotionQuaternion else {
            print("Failed getting device attitude in correctedCoreMotionQuaternion")
            return nil
        }
        return correctionQuaternion * coreMotionQuaternion
    }
    
    private var adjustedQuaternion: simd_quatf? {
        guard let correctedCoreMotionQuaternion else {
            print("Failed getting device attitude in adjustedQuaternion")
            return nil
        }
        return correctedCoreMotionQuaternion * virtualCameraAdjustmentQuaternion
    }
    
    /// For Virtual Reality (VR) mode, we have a simulated "virtual" camera.
    /// We want that simulated camera to respond to the device's movement, to give the impression that it is a real camera.
    /// This function gathers the device orienation at the current instant, and makes the necessary adjustments to the virtual camera.
    /// - Parameters:
    ///   - motion: Core Motion of the device
    func updateVirtualCameraTransform(with motion: CMDeviceMotion) {
        attitude = motion.attitude
        if let adjustedQuaternion {
            vrCameraAnchor?.children.first?.transform.rotation = adjustedQuaternion
        }
    }
    
    // MARK: - Setup
    
    func build(onComplete: @escaping () -> Void) {
        DispatchQueue.main.async {
            //self.anchor = getNewAnchor(for: Constants.anchorWidth)
            self.buildFloor()
            self.loadModel()
            self.loadTriangulo()
            self.addPointLight()
            self.buildFireworks()
            self.audioResources = AudioResources()
            
            if self.arView.cameraMode == .nonAR {
                self.activateVrScene()
            } else if let anchor = self.anchor {
                // Add the horizontal plane anchor to the scene
                self.arView.scene.anchors.append(anchor)
            }
            
            onComplete()
        }
    }
    
    /// Create a floor that sits with the anchor to visualize its location
    func buildFloor() {
        // Generate the floor, which is created as a `ModelEntity` so that it satisfies `HasCollision` which is used for dragging the table
        let floorMesh = MeshResource.generatePlane(width: 0.001, depth: 0.001)
        floor = ModelEntity(mesh: floorMesh, materials: [OcclusionMaterial()])
        if let floor { //}, let anchor {
            floor.addPhysics(material: Materials.wood, mode: .static)
            floor.position = SIMD3<Float>()
            //anchor.addChild(floor)
        }
        
        // Generate the occluder, which is a cube that obscures the table during times when you are setting a new anchor
        let occluderMesh = MeshResource.generateBox(width: Constants.anchorWidth, height: Constants.anchorWidth, depth: 2 * Constants.anchorWidth)
        occluder = ModelEntity(mesh: occluderMesh, materials: [OcclusionMaterial()])
        occluder?.position.y = -Constants.anchorWidth-0.02
        if let occluder, let floor {
            occluder.setParent(floor)
        }
    }

    /// Load the La Rana scene
    func loadModel() {
        if let larana = try? Entity.load(named: "TableAndLaRana.usdz") {
            self.buildModel(for: larana)
        }
    }
    
    /// Build the El Triangulo scene for VR mode
    func loadTriangulo() {
        guard let triangulo = try? Entity.load(named: "Triangulo.usdz") else {
            print("Failed to load the El Triangulo entity")
            return
        }
    
        buildContactSurfaces(inTriangulo: triangulo)
        
        // Add an opacity component so that the Triangulo scene can fade in and out when switching to AR
        if #available(iOS 18.0, *) {
            let opacityComponent = OpacityComponent(opacity: 1.0)
            triangulo.components.set(opacityComponent)
        }

        // Add a light that imitates the sun
        let directionalLight = DirectionalLight()
        directionalLight.shadow?.maximumDistance = 15
        directionalLight.shadow?.depthBias = 1
        directionalLight.look(at: [-1, 0, -1], from: [0, 15, 0], relativeTo: nil)
        triangulo.addChild(directionalLight)
        
        // Make the ground texture be tiled
        /*if let ground = triangulo.findEntity(named: "Ground_Cube") as? ModelEntity,
           var material = ground.model?.materials.first as? PhysicallyBasedMaterial {
            material.textureCoordinateTransform = .init(scale: SIMD2<Float>(x: 1, y: 1), rotation: 0.0)
            ground.model?.materials[0] = material
        }*/
            
        self.triangulo = triangulo
            
    }
    
    /// Adds physics to the coin and table contact surfaces, and updates the reference to larana in this model so it gets published
    func buildModel(for larana: Entity) {
        buildCoin(in: larana)
        buildContactSurfaces(inLarana: larana)
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
    
    func buildContactSurfaces(inLarana larana: Entity) {
        // Give the target a collision component, but no physics
        addPhysics(to: ["target"], in: larana, material: nil, mode: nil)
        
        // Add contact to the turf sections
        let turfEntities = [
            "TableMainTurf_Cube_017", "TableBackTurf_Cube_016", "TableWallLeftTurf_Cube_018", "TableWallRightTurf_Cube_019"]
        addPhysics(to: turfEntities, in: larana, material: Materials.turf, mode: .kinematic, collisionGroup: tableGroup)
        
        // Add contact to La Rana
        let metalEntities = ["Mesh"]
        addPhysics(to: metalEntities, in: larana, material: Materials.metal, mode: .kinematic, collisionGroup: tableGroup)

        // Add contact to the wood frame
        let woodEntities = [
            "ChuteFront_Cube_011", "ChuteSlope_Cube_012", "ChuteRight_Cube_013", "ChuteLeft_Cube_014",
            "LegFrontRight_Cube", "LegFrontLeft_Cube_001", "LegRearRight_Cube_002", "LegRearLeft_Cube_003",
            "SupportLowerFront_Cube_008", "SupportLowerRear_Cube_009", "SupportLowerCenter_Cube_010"
        ]
        addPhysics(to: woodEntities, in: larana, material: Materials.wood, mode: .kinematic)
        
        let tableEntities = ["TableBack_Cube_005", "TableWallRight_Cube_006", "TableWallLeft_Cube_007", "TableMain_Cube_015"]
        addPhysics(to: tableEntities, in: larana, material: Materials.wood, mode: .kinematic, collisionGroup: tableGroup)
    }
    
    func buildContactSurfaces(inTriangulo triangulo: Entity) {
        let trianguloEntities = ["Ormaetxe", "Plane",
                                 "Ardibeltz", "Bizitza", "Xukela",
                                 "Table", "Table_001", "Table_005", "Table_006",
                                 "Barrel", "Barrel_001", "Barrel_002", "Barrel_003"]
        addPhysics(to: trianguloEntities, in: triangulo, material: Materials.wood, mode: .static, collisionGroup: tableGroup)
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
        lightEntity.setParent(floor)
    }
    
    /// Build firework entity for succesful hits of the target
    func buildFireworks() {
        fireworkEmitter = Entity()
        fireworkEmitter?.position = SIMD3<Float>(0, 0.7, 0.1)
        fireworkEmitter?.setParent(floor)
        
        if #available(iOS 18.0, *) {
            var emitterComponent = ParticleEmitterComponent.Presets.fireworks
            emitterComponent.isEmitting = false
            fireworkEmitter?.components.set(emitterComponent)
        }
    }
    
    // MARK: - Anchor
    
    /// Sets the anchor location based on either a raycast to the point a user tapped, or a default
    /// - Parameters:
    ///     - location: The location where the user tapped
    /// - Returns: Whether the new anchor was successfully placed
    func resetAnchorLocation(to location: CGPoint? = nil) -> Bool {
        var newAnchor: AnchorEntity?
        if let location, let ray = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal).first {
            // Set the location of the anchor based upon a raycast to a point that the user tapped on screen
            newAnchor = AnchorEntity(world: ray.worldTransform)
            print("Set new anchor at \(newAnchor!.position)")
        } else {
            // Set the location of the anchor based upon the default
            newAnchor = getNewAnchor(for: Constants.anchorWidth)
        }
        guard let newAnchor else {
            print("failed to get a new anchor")
            return false
        }
        
        setAnchor(to: newAnchor)
        
        return true
    }
    
    private func setAnchor(to newAnchor: AnchorEntity) {
        if let floor {
            floor.removeFromParent()
            floor.position = SIMD3<Float>()
            newAnchor.addChild(floor)
        }
        if let anchor {
            arView.scene.anchors.remove(anchor)
        }
        arView.scene.anchors.append(newAnchor)
        anchor = newAnchor
        
        makeTableVisible()
    }
    
    func makeTableVisible() {
        if let floor, let larana {
            larana.setParent(floor)
            larana.position.y = -Constants.laranaHeight
            let transform = Transform(translation: SIMD3<Float>())
            larana.move(to: transform, relativeTo: floor, duration: 1.0)
            generateShowTableAudio()
        }
    }
    
    func hideTable() {
        if let floor, let larana {
            let transform = Transform(translation: SIMD3<Float>(0, -Constants.laranaHeight, 0))
            larana.move(to: transform, relativeTo: floor, duration: 1.0)
            generateHideTableAudio()
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                larana.removeFromParent()
            }
        }
    }
    
    // MARK: - Gestures
    
    var moveGestureRecognizers: [any EntityGestureRecognizer]?
    
    /// Enables gestures to allow single finger move or two finger rotate to all entities that are child to the floor, specifically the table and  La Rana model
    func addMoveGesture() {
        if let floor {
            moveGestureRecognizers = arView.installGestures([.translation, .rotation], for: floor)
        }
    }
    
    /// Removes gestures to allow moving the table and La Rana
    func removeMoveGesture() {
        moveGestureRecognizers?.forEach { recognizer in
            if let idx = arView.gestureRecognizers?.firstIndex(of: recognizer) {
                arView.gestureRecognizers?.remove(at: idx)
            }
        }
        moveGestureRecognizers = nil
    }
    
    /// Provides a single random float component to be applied to a randomized coin angular velocity
    private var randomAngularRate: Float {
        Float.random(in: Constants.angularRateRange)
    }
    
    /// Provides three random float components to be applied to a randomized coin angular velocity
    private var randomAngularRateVector: SIMD3<Float> {
        return SIMD3<Float>(randomAngularRate, randomAngularRate, randomAngularRate)
    }
    
    func tossCoin(with velocity: SIMD3<Float>, index: Int? = nil) {
        // We get the current anchor here to ensure if there was a dynamic update, the correct anchor is parented
        guard let anchor else {
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
        let cameraTransformFromAnchor = getCameraTransformRelativeTo(entity: anchor)

        // Set the position of the fresh coin to slightly below the device prior to toss
        generatedCoin.position = cameraTransformFromAnchor.translation
        generatedCoin.position.y -= 0.1
        
        // Get a speed adjustment for distance
        var velocity = velocity
        if let target = anchor.findEntity(named: "target") {
            let cameraTransformFromTarget = getCameraTransformRelativeTo(entity: target)

            // Calculate initial velocity needed to hit target given the vector distance to the target and initial angle
            let d = cameraTransformFromTarget.translation.z // horizontal distance to target
            let h = -cameraTransformFromTarget.translation.y // vertical distance to target
            let g: Float = 9.8
            let theta = Constants.initialLaunchAngle
            let v0 = sqrt(2) * d * sqrt(g / (d*sin(2*theta) - h*cos(2*theta) - h))

            // This weight is the amount we should trust the "flick" velocity
            let weight = Constants.userFlickVelocityWeight
            velocity.y = weight * velocity.y + (1 - weight) * v0 * sin(theta)
            velocity.z = weight * velocity.z - (1 - weight) * v0 * cos(theta)
        }

        // Set a new PhysicsMotionComponent to add initial velocity, and randomize angular velocity
        generatedCoin.components.set(PhysicsMotionComponent(
            linearVelocity: velocity.rotatedFrom(cameraTransform.matrix),
            angularVelocity: randomAngularRateVector
        ))
        
        // Add contact to the coin
        generatedCoin.addPhysics(material: Materials.metal, mode: .dynamic)
        
        // Set the parent to the anchor so that it exists in the scene
        generatedCoin.setParent(anchor)
        
        // Add to the array of coins, and clear if there are too many in play
        if coins.count >= Constants.maxNumberOfCoins {
            // Look for a coin that is either on the ground (<0.2) or on the table (>0.6), avoid removing coins that are in the chute
            if let idx = coins.firstIndex(where: { $0.position.y < 0.2 }) ?? coins.firstIndex(where: { $0.position.y > 0.6 }) {
                let oldCoin = coins.remove(at: idx)
                oldCoin.removeFromParent()
                print("Removed \(oldCoin.name), coins.count = \(coins.count)")
            }
        }
        coins.append(generatedCoin)
        generateThrowAudio(for: generatedCoin)
    }
    
    func addFilterAfterHitTarget(to name: String) {
        if let anchor, let coin = anchor.findEntity(named: name) {
            addCollisionFilter(to: coin, group: coinGroup, mask: .all.subtracting(tableGroup))
            reduceVelocity(of: coin, anchor: anchor)
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
        material: PhysicsMaterialResource? = nil,
        mode: PhysicsBodyMode? = nil,
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
    
    /// Sets the collision group and the mask of an entity, used to disable collisions of the coin with the table to emulate dropping through the target hole
    func addCollisionFilter(to entity: Entity, group: CollisionGroup = .all, mask: CollisionGroup = .all) {
        if var collision = entity.components[CollisionComponent.self] {
            collision.filter = CollisionFilter(group: group, mask: mask)
            entity.components[CollisionComponent.self] = collision
            print("Collision filter \(collision.filter) added to \(entity.name)")
        }
        
        if #available(iOS 18.0, *) {
            self.showFireworks()
        }
    }
    
    /// Reduce the coin velocity to make it more likely to drop into the chute after hitting the target
    private func reduceVelocity(of coin: Entity, anchor: Entity) {
        DispatchQueue.main.async {
            // Need to remove child before setting the motion component then add after to make it take effect
            anchor.removeChild(coin)
            if let motion = coin.components[PhysicsMotionComponent.self] {
                // To slow down the coin motion, we multiply by 0.25
                var newVelocity = 0.2 * motion.linearVelocity
                
                // If we find the hole entity, direct the motion vector into that hole, with the same velocity
                if let tableHole = anchor.findEntity(named: "TableHole_Cylinder") {
                    let coinPosition = coin.position(relativeTo: anchor)
                    let holePosition = tableHole.position(relativeTo: anchor)
                    let directionToHole = normalize(holePosition - coinPosition)
                    newVelocity = directionToHole * length(newVelocity)
                }
                
                // Update the linear velocity, but keep angular velocity the same
                coin.components.set(PhysicsMotionComponent(
                    linearVelocity: newVelocity,
                    angularVelocity: motion.angularVelocity
                ))
                print("After hitting the target, set coin velocity to \(motion.linearVelocity)")
            }
            anchor.addChild(coin)
        }
    }
    
    private struct Materials {
        static let metal = PhysicsMaterialResource.generate(friction: 0.8, restitution: 0.7)
        static let turf = PhysicsMaterialResource.generate(friction: 0.8, restitution: 0.2)
        static let wood = PhysicsMaterialResource.generate(friction: 0.8, restitution: 0.5)
    }
    
    // MARK: - Effects
    
    private var lastTextEntity: ModelEntity? = nil
    private var lastCoinName: String? = nil

    /// Generates the text in the AR view notifying the user what their last tossed coin collided with
    func generateFloatingText(text: String, color: String = "white", name: String? = nil) {
        guard let target = anchor?.findEntity(named: "target") else {
            print("generatingFloatingText could not obtain the target entity")
            return
        }
        
        // Set material to be the specified color depending on event type
        let material = SimpleMaterial(
            color: color == "white" ? .white : color == "green" ? .green : color == "blue" ? .blue : .red,
            roughness: 0,
            isMetallic: false
        )
        
        // The frame is set to be fairly large to contain the whole text
        let containerFrame = CGRect(x: -1, y: -1, width: 2.0, height: 1)

        // Generate the mesh and use it to create the entity
        let font: UIFont = UIFont(name: "Moderna", size: 0.015) ?? .systemFont(ofSize: 0.015)
        let textMesh = MeshResource
            .generateText(text,
                          extrusionDepth: 0.005,
                          font: font,
                          containerFrame: containerFrame,
                          alignment: .center,
                          lineBreakMode: .byWordWrapping
        )

        let textEntity = ModelEntity(mesh: textMesh, materials: [material])

        // Initial position of the floating text is just above the target
        textEntity.position = Constants.initialTextPosition + 0.5 * .random(in: Constants.randomTextRange)
        textEntity.setParent(target)
        
        // The text is animated to make it grow, move upward, and towards the player
        let randomRotation = 2 * SIMD3<Float>.random(in: Constants.randomTextRange)
        var animationTransform = Transform(pitch: randomRotation.x, yaw: randomRotation.y, roll: randomRotation.z)
        animationTransform.scale = SIMD3<Float>(repeating: Constants.textScale)
        animationTransform.translation = Constants.constantTextTranslation + .random(in: Constants.randomTextRange)
        textEntity.move(to: animationTransform, relativeTo: target, duration: 1.0)
        
        // If this coin was the same as for the last floating text, remove that one and replace it with this
        if name == lastCoinName {
            lastTextEntity?.removeFromParent()
        }
        lastTextEntity = textEntity
        lastCoinName = name
        
        // Schedule the text to disappear after a second
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
            let scaleOutTransform = Transform(scale: SIMD3<Float>(repeating: 0))
            textEntity.move(to: scaleOutTransform, relativeTo: target, duration: 0.25)
        }
        Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
            textEntity.removeFromParent()
        }
    }
    
    func generateAudio(for entityName: String, of hit: CoinHit) {
        guard let entity = anchor?.findEntity(named: entityName) else {
            print("generateAudio failed to get \(entityName)")
            return
        }
        generateAudio(for: entity, of: hit)
    }
    
    func generateAudio(for entity: Entity, of hit: CoinHit) {
        guard let targetAudio = audioResources?.getResource(for: hit) else {
            return
        }
        generateAudio(for: entity, with: targetAudio)
    }
    
    func generateShowTableAudio() {
        guard let targetAudio = audioResources?.shows.randomElement(), let floor else {
            return
        }
        generateAudio(for: floor, with: targetAudio)
    }
    
    func generateHideTableAudio() {
        guard let targetAudio = audioResources?.hides.randomElement(), let floor else {
            return
        }
        generateAudio(for: floor, with: targetAudio)
    }
    
    func generateThrowAudio(for entity: Entity) {
        guard let targetAudio = audioResources?.tosses.randomElement() else {
            return
        }
        generateAudio(for: entity, with: targetAudio)
    }
    
    func generateAudio(for entity: Entity, with targetAudio: AudioFileResource) {
        let audioEntity = Entity()
        audioEntity.position = entity.position
        if let floor {
            audioEntity.setParent(floor)
        }
        
        let audioController = audioEntity.prepareAudio(targetAudio)
        if let motion = entity.components[PhysicsMotionComponent.self] {
            audioController.gain = 10 * Double(log10(motion.linearVelocity.magnitudeSquared / 4.0))
        }
        audioController.play()
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
            audioEntity.removeFromParent()
        }
    }
    
    /// Turn on the emission of fireworks after hitting the target, and turn off after some period of time
    @available(iOS 18.0, *)
    func showFireworks() {
        // Turn the emitter on, and generate a burst
        fireworkEmitter?.components[ParticleEmitterComponent.self]?.isEmitting = true
        fireworkEmitter?.components[ParticleEmitterComponent.self]?.burst()
        
        // Play firework audio
        var counter = 0
        if let target, let targetAudio = audioResources?.fireworks.randomElement() {
            generateAudio(for: target, with: targetAudio)
        }
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if let target = self.target, let targetAudio = self.audioResources?.fireworks.randomElement() {
                self.generateAudio(for: target, with: targetAudio)
            }
            self.fireworkEmitter?.components[ParticleEmitterComponent.self]?.burst()
            
            counter += 1
            if counter >= 2 {
                timer.invalidate() // Stop the timer after 3 repetitions
            }
        }
        
        // Stop the fireworks after a delay
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            self.fireworkEmitter?.components[ParticleEmitterComponent.self]?.isEmitting = false
        }
    }
    
    /// Make sure the fireworks have stopped emitting when toggling betwene VR/AR, as that may have been causing a crash
    func stopFireworks() {
        if #available(iOS 18.0, *) {
            self.fireworkEmitter?.components[ParticleEmitterComponent.self]?.isEmitting = false
        }
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let anchorWidth: Float = 0.7
        static let anchorHeight: Float = 0.02
        static let laranaHeight: Float = 0.9
        static let coinName = "coin"
        static let initialLaunchAngle: Float = .pi / 6
        static let userFlickVelocityWeight: Float = 0.2
        static let angularRateRange = Float(-50)...Float(50)
        static let initialTextPosition = SIMD3<Float>(0, 0.15, 0)
        static let textScale: Float = 6.28
        static let constantTextTranslation = SIMD3<Float>(x: 0, y: 0.3, z: 0.2)
        static let randomTextRange = Float(-0.1)...Float(0.1)
        static let maxNumberOfCoins = 20
    }
}
