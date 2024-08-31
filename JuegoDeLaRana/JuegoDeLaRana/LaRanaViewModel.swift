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
    }

    func toggleMove() {
        state = state == .move ? .play : .move
        
        if let floor = entities.floor {
            if state == .move {
                entities.addMoveGesture()
                print("Added gestures to the floor")
            } else {
                entities.removeMoveGesture()
                print("Removed gestures from the floor")
            }
        }
    }
}
