//
//  Entity+Extensions.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 8/30/24.
//

import Foundation
import RealityKit

extension Entity {
    var modelComponent: ModelComponent? {
        if let modelComponent = components[ModelComponent.self] {
            return modelComponent as? ModelComponent
        } else {
            if let childWithModel = children.first(
                where: { $0.components[ModelComponent.self] != nil }
            ) {
                if let modelComponent = childWithModel.components[ModelComponent.self]{
                    return modelComponent as? ModelComponent
                }
            }
        }
        return nil
    }
    
    func addPhysics(material: PhysicsMaterialResource, mode: PhysicsBodyMode) {
        guard let modelComponent else {
            print("No child with a ModelComponent found in \(self.name)")
            return
        }
        // Generate collision shapes based on the model's mesh
        let shape = ShapeResource.generateConvex(from: modelComponent.mesh)
        let collisionComponent = CollisionComponent(shapes: [shape])
        components.set(collisionComponent)

        // Create and add a PhysicsBodyComponent
        let physicsBody = PhysicsBodyComponent(
            massProperties: .default,
            material: material,
            mode: mode
        )
        components.set(physicsBody)
        
        print("Physics and collision components added to \(self)")

    }
}
