//
//  LaRanaViewModel.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 8/30/24.
//

import Foundation
import SwiftUI
import TipKit
import RealityKit

enum GameState: String {
    case new = "New"
    case loading = "3D model is loading ..."
    case play = "Flick upward to toss a coin, try to get it in the frog's mouth"
    case resetting = "Tap on the ground to place the table"
    case move = "Drag the table with one finger to move, or with two fingers to rotate"
}

class LaRanaViewModel: ObservableObject {
    @Published var entities: ARViewEntities
    @Published var state: GameState = .new
    
    var cameraMode: ARView.CameraMode {
        get {
            entities.arView.cameraMode
        }
        set(newCameraMode) {
            entities.toggleArCameraMode(to: newCameraMode)
        }
    }
    
    init(cameraMode: ARView.CameraMode = .nonAR) {
        state = .loading
        entities = ARViewEntities(cameraMode: cameraMode)
        entities.build {
            // When the entities have completed their build, toggle to either the resetting (AR) or play (nonAR) state depending on camera mode
            withAnimation {
                switch self.cameraMode {
                case .ar: self.state = .resetting
                case .nonAR: self.state = .play
                @unknown default:
                    fatalError("Received an unknown ARView.CameraMode after building the entities")
                }
            }
            
            // I don't want the tip to show instantly, this delays it, and only shows if the current state matches the tip
            Timer.scheduledTimer(withTimeInterval: Constants.delayBeforeTip, repeats: false) { _ in
                switch self.state {
                case .resetting: TipForResetButton.hasToggledToResetMode = true
                case .play: TipForCoinFlick.hasToggledToPlayMode = true
                default: print("After delay, state was different from .resetting or .play")
                }
            }
        }
    }
    
    // MARK: - Scores
    
    @Published var nTossed = 0
    var coinFirstHitTimes = [String: Date]()
    @Published var coinHits = [String: CoinHit]()
    var nHitLaRana: Int {
        coinHits.values.filter { $0 == .larana }.count
    }
    var nHitTarget: Int {
        coinHits.values.filter { $0 == .hole }.count
    }

    // MARK: - Button Intents
    
    /// Handle the user tapping on the reset button in the overlay view by either putting the game in `.resetting` mode where they can choose a
    /// new table position, or getting an automatically generated anchor and placing the table before toggling to `.play` mode.
    func resetAnchor() {
        // Only respond to taps on the reset button when in AR mode
        if cameraMode == .nonAR {
            if state == .resetting || state == .move {
                state = .play
            }
            return
        }
        
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
                    Timer.scheduledTimer(withTimeInterval: Constants.delayBeforeTip, repeats: false) { _ in
                        if self.state == .play {
                            TipForCoinFlick.hasToggledToPlayMode = true
                        }
                    }
                    state = .play
                }
            }
        }
    }

    /// Handles the user tapping on the move button in the overlay view by toggling ether in or out of the mode where you can move a table with drag gesture
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
                Timer.scheduledTimer(withTimeInterval: Constants.delayBeforeTip, repeats: false) { _ in
                    if self.state == .move {
                        TipForMoveButton.hasToggledToMoveMode = true
                    }
                }
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
    /// - Parameters:
    ///   - location: The location where the user tapped
    func handleTapGesture(location: CGPoint) {
        if state == .resetting {
            if entities.resetAnchorLocation(to: location) { // Checks that the new anchor succeeded
                withAnimation {
                    Timer.scheduledTimer(withTimeInterval: Constants.delayBeforeTip, repeats: false) { _ in
                        if self.state == .play {
                            TipForCoinFlick.hasToggledToPlayMode = true
                        }
                    }
                    state = .play
                }
            }
        }
    }
    
    /// When the game is in play mode and the user flicks upward from the bottom of the screen, toss a coin
    /// - Parameters:
    ///   - location: The ending location of the flick in pixel units
    ///   - velocity: The velocity of the flick in pixel units
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
    
    ///. Checks what type of entity the coin collided with, then triggers game score updates, text displays, collision filtering, or
    func handleCollisions(for event: CollisionEvents.Began) {
        guard let coin = event.entityA.asCoin else {
            return
        }
        
        // Ignore collisions too long after the launch of the coin
        if let launchTime = coinFirstHitTimes[coin.name] {
            if Date.now.timeIntervalSince(launchTime) > 0.5 {
                return
            }
        } else {
            coinFirstHitTimes[coin.name] = Date.now
        }
        
        // Characterize the type of hit (initial determination)
        var thisHit: CoinHit =
            event.entityB.name == "target" ? .hole :
            event.entityB.name == "Mesh" ? .larana :
            event.entityB.name.contains("Turf") ? .turf : .ground
        
        // Handle likelihood that the coin was on target in this event.
        // If its on target, then set up so that it falls through, otherwise toggle to a .larana hit
        let prob = thisHit == .hole ? calculateOnTargetProbability(coin: coin) : 0.0
        if prob > 0.5 {
            thisHit = .hole
            entities.addFilterAfterHitTarget(to: coin.name)
        } else {
            thisHit = thisHit == .hole ? .larana : thisHit
        }

        if let coinScore = coinHits[coin.name], thisHit.rawValue <= coinScore.rawValue {
            // The existing hit score exceeded this one, don't update
        } else {
            // This is either a first hit or a better score than previous hit, update the score
            withAnimation {
                coinHits[coin.name] = thisHit
            }
            
            // Provide the alert audio, text and color that will float above the target
            entities.generateAudio(for: coin.name, of: thisHit)
            let alert = CoinHitAlert(for: thisHit)
            entities.generateFloatingText(
                text: alert.announcement,
                color: alert.color,
                name: coin.name
            )
            print("\(coin.name) collided with \(thisHit)")
        }
    }
    
    /// Checks whether the coin is expected to go into the frog's mouth based on its velocity direction relative to the center of the hole
    func calculateOnTargetProbability(coin: Entity) -> Float {
        guard let target = entities.target, let floor = entities.floor else {
            return 0.0
        }
        
        if let motion = coin.components[PhysicsMotionComponent.self] {
            let floorTransform = floor.transformMatrix(relativeTo: nil)
            let relPosInTargetFrame = coin.position(relativeTo: target).rotatedTo(floorTransform)
            let velInTargetFrame = motion.linearVelocity.rotatedTo(floorTransform)
            
            // Project forward in time to where the coin will be located when it crosses the target plane
            let timeUntilHit = -relPosInTargetFrame.z / velInTargetFrame.z
            var relPosWhenCoinHitsTarget = relPosInTargetFrame + velInTargetFrame * timeUntilHit
            relPosWhenCoinHitsTarget.y -= 0.5 * 9.8 * pow(timeUntilHit, 2) // adjust for gravity
            
            // Calculate probability score using logistic regression equation
            // intercept = 2.007849951750073, coefficients = [ 0.973165   -0.27587833 -0.01048093 -0.29251362]
            let x = 100 * relPosWhenCoinHitsTarget.x
            let y = 100 * relPosWhenCoinHitsTarget.y
            let x2 = pow(x, 2)
            let y2 = pow(y, 2)
            let gama = 2.007849951750073 + 0.973165*x - 0.27587833*x2 - 0.01048093*y - 0.29251362*y2
            let prob = 1 / (1 + exp(-gama))
            print("\(coin.name) collision event data = [\(x), \(y), \(velInTargetFrame.csv)] prob = \(prob)")
            return prob
        }
        return 0.0
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let flickThreshold: CGFloat = -1000
        static let pixelToMeterPerSec: Float = 0.001
        static let delayBeforeTip: Double = 3
    }
}

extension Entity {
    var asCoin: Entity? {
        name.contains("coin") ? self : nil
    }
}
