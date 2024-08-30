//
//  Entity+Extensions.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 8/30/24.
//

import Foundation
import RealityKit

extension Entity {
    func addPhysics(material: PhysicsMaterialResource, mode: PhysicsBodyMode) {
        if let childWithModel = children.first(
            where: { $0.components[ModelComponent.self] != nil }
        ) {
            if let modelComponent = childWithModel.components[ModelComponent.self] as? ModelComponent {
                
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
        } else {
            print("No child with a ModelComponent found")
        }
    }
}
