//
//  LaRanaViewModel.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 8/30/24.
//

import Foundation

enum GameState {
    case play
    case resetting
    case move
    case rotate
}

class LaRanaViewModel: ObservableObject {
    @Published var entities = ARViewEntities()
    @Published var state = GameState.play
    
    // MARK: - Button Intents
    
    func resetAnchor() {
        state = .resetting
        entities.resetAnchorLocation()
        state = .play
    }

    func toggleMove() {
        state = state == .move ? .play : .move
        
        if entities.floor != nil {
            if state == .move {
                entities.addMoveGesture()
                print("Added gestures to the floor")
            } else {
                entities.removeMoveGesture()
                print("Removed gestures from the floor")
            }
        }
    }
    
    // MARK: - Gesture Intents
    
    func handleFlickGesture(location: CGPoint, velocity: CGPoint) {
        // If we are in play mode, and the gesture is a flick upwards, toss a coin
        if state == .play && velocity.y < Constants.flickThreshold {
            print("Flick detected at location: \(location), velocity: \(velocity)")
            
            // Convert velocity in pixels to a coin velocity in meters/second
            let coinVelocity = SIMD3<Float>(
                Constants.pixelToMeterPerSec * Float(velocity.x),
                -Constants.pixelToMeterPerSec * Float(velocity.y), // negative, because a flick upward is a negative number
                Constants.pixelToMeterPerSec * Float(velocity.y)
            )
            
            // Toss the coin
            entities.tossCoin(with: coinVelocity)
        }
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let flickThreshold: CGFloat = -1000
        static let pixelToMeterPerSec: Float = 0.001
    }
}
