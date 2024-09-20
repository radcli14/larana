//
//  LaRanaTips.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 9/18/24.
//

import SwiftUI
import TipKit

/// Provides a tip corresponding to the reset button in the overlay view
struct TipForResetButton: Tip {
    private let resetAnchorType: OverlayViewButtonType = .resetAnchor
    
    @Parameter
    static var hasToggledToResetMode: Bool = false

    var title: Text {
        Text(resetAnchorType.text)
    }


    var message: Text? {
        Text(resetAnchorType.activeForState.rawValue)
    }


    var image: Image? {
        Image(systemName: resetAnchorType.icon)
    }
    
    var rules: [Rule] {
        [#Rule(Self.$hasToggledToResetMode) { $0 == true }]
    }
}

/// Provides a tip corresponding to the move button in the overlay view
struct TipForMoveButton: Tip {
    private let moveType: OverlayViewButtonType = .moveTable
    
    @Parameter
    static var hasToggledToMoveMode: Bool = false
    
    var title: Text {
        Text(moveType.text)
    }


    var message: Text? {
        Text(moveType.activeForState.rawValue)
    }


    var image: Image? {
        Image(systemName: moveType.icon)
    }
    
    var rules: [Rule] {
        [#Rule(Self.$hasToggledToMoveMode) { $0 == true }]
    }
}

/// Provides a tip explaining that the user should flick a coin
struct TipForCoinFlick: Tip {
    @Parameter
    static var hasToggledToPlayMode: Bool = false
    
    var title: Text {
        Text("Play \"La Rana\"")
    }
    
    var message: Text? {
        Text(GameState.play.rawValue)
    }
    
    var image: Image? {
        Image(systemName: "hand.point.up")
    }
    
    var rules: [Rule] {
        [#Rule(Self.$hasToggledToPlayMode) { $0 == true }]
    }
}
