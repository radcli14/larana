//
//  LaRanaViewModel.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 8/30/24.
//

import Foundation
import SwiftUI

enum CoinHit: Int {
    case ground = 0
    case turf = 1
    case larana = 2
    case hole = 3
}

enum GameState: String {
    case new = "New"
    case loading = "3D model is loading ..."
    case play = "To play: flick to toss a coin"
    case resetting = "Tap to place the table"
    case move = "To move: drag with one finger, or rotate with two fingers"
}

class LaRanaViewModel: ObservableObject {
    @Published var entities = ARViewEntities()
    @Published var state: GameState = .new

    init() {
        state = .loading
        entities.build {
            withAnimation {
                self.state = .resetting
            }
        }
    }
    
    // MARK: - Scores
    
    @Published var nTossed = 0
    @Published var coinHits = [String: CoinHit]()
    var nHitLaRana: Int {
        coinHits.values.filter { $0 == .larana }.count
    }
    var nHitTarget: Int {
        coinHits.values.filter { $0 == .hole }.count
    }

    // MARK: - Button Intents
    
    func resetAnchor() {
        withAnimation {
            // Make sure flick gestures are removed if currently in move state, will switch to resetting state
            if state == .move {
                toggleMove()
            }
            
            if state == .play {
                // Put the app into a state where the user will tap to update the anchor
                entities.hideTable()
                state = .resetting
                
            } else if state == .resetting {
                // Reset the anchor to an automatically determined position
                if entities.resetAnchorLocation() { // Checks that the new anchor succeeded
                    state = .play
                }
            }
        }
    }

    func toggleMove() {
        print("Tapped toggleMove with state = \(state)")
        // Update the state based on the user tap
        withAnimation {
            if state == .move {
                state = .play
            } else if state == .play {
                state = .move
            } else {
                // This toggle should have no effect if not in either the play or move state, such as if you tapped during the loading or reset state
                return
            }
        }
        
        // Add or remove gestures from the table
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
    
    ///. When the user taps during reset anchor mode, this resets the anchor and puts the game in play mode
    func handleTapGesture(location: CGPoint) {
        if state == .resetting {
            if entities.resetAnchorLocation(to: location) { // Checks that the new anchor succeeded
                withAnimation {
                    state = .play
                }
            }
        }
    }
    
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
            withAnimation {
                nTossed += 1
            }
            entities.tossCoin(with: coinVelocity, index: nTossed)
        }
    }
    
    // MARK: - Collisions
    
    func handleCollisions(between nameA: String, and nameB: String) {
        if nameA.contains("coin") {
            // Set the enum based on what the coin collided with
            let thisHit: CoinHit = nameB == "target" ? .hole : nameB == "Mesh" ? .larana : nameB.contains("Turf") ? .turf : .ground
            
            if let coinScore = coinHits[nameA], thisHit.rawValue <= coinScore.rawValue {
                // The existing hit score exceeded this one, don't update
            } else {
                // This is either a first hit or a better score than previous hit, update the score
                withAnimation {
                    coinHits[nameA] = thisHit
                }
                entities.generateFloatingText(
                    text: thisHit == .hole ? "¡exito!" : thisHit == .larana ? "¡cerca!" : "fallaste",
                    color: thisHit == .hole ? "green" : thisHit == .larana ? "white" : "red",
                    name: nameA
                )
                print("\(nameA) collided with \(thisHit)")
            }
            
            if thisHit == .hole {
                // Add filter so it falls through the table
                entities.addFilterAfterHitTarget(to: nameA)
            }
        }
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let flickThreshold: CGFloat = -1000
        static let pixelToMeterPerSec: Float = 0.001
    }
}
