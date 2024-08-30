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
    
    @Published var state = GameState.play
    
    // MARK: - Button Intents
    
    func resetAnchor() {
        state = .resetting
    }
    
    func toggleMove() {
        state = state == .move ? .play : .move
    }
    
    func toggleRotate() {
        state = state == .rotate ? .play : .rotate
    }
}
