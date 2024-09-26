//
//  LaRanaTips.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 9/18/24.
//

import SwiftUI
import TipKit

/// Provides a tip suggesting the user tap the reset button to select a new anchor location
struct TipForNewLocation: Tip {
    @Parameter(.transient)
    static var userShouldSetAnchor: Bool = false

    var title: Text {
        Text("Set a new location")
    }


    var message: Text? {
        Text("Tap to place the game board")
    }


    var image: Image? {
        Image(systemName: OverlayViewButtonType.resetAnchor.icon)
    }
    
    var rules: [Rule] {
        [#Rule(Self.$userShouldSetAnchor) { $0 == true }]
    }
    
    var options: [Option] {[
        Tips.MaxDisplayCount(1),
        //Tips.IgnoresDisplayFrequency(true)
    ]}
}


/// Provides a tip corresponding to the reset button in the overlay view
struct TipForResetButton: Tip {
    private let resetAnchorType: OverlayViewButtonType = .resetAnchor
    
    @Parameter(.transient)
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
    
    var options: [Option] {[
        Tips.MaxDisplayCount(1),
        //Tips.IgnoresDisplayFrequency(true)
    ]}
}

/// Provides a tip corresponding to the move button in the overlay view
struct TipForMoveButton: Tip {
    private let moveType: OverlayViewButtonType = .moveTable
    
    @Parameter(.transient)
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
    
    var options: [Option] {[
        Tips.MaxDisplayCount(1),
        //Tips.IgnoresDisplayFrequency(true)
    ]}
}

/// Provides a tip explaining that the user should flick a coin
struct TipForCoinFlick: Tip {
    @Parameter(.transient)
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
    
    var options: [Option] {[
        Tips.MaxDisplayCount(1),
        //Tips.IgnoresDisplayFrequency(true)
    ]}
}

/// Provides a tip suggesting the user try the AR mode
struct TipForArMode: Tip {
    @Parameter(.transient)
    static var hasPlayedEnoughToGoToAr: Bool = false
    
    var title: Text {
        Text("Try Augmented Reality (AR)")
    }
    
    var message: Text? {
        Text("Play \"La Rana\" inside your real-world by toggling to AR mode")
    }
    
    var image: Image? {
        Image(systemName: "arkit")
    }
    
    var rules: [Rule] {
        [#Rule(Self.$hasPlayedEnoughToGoToAr) { $0 == true }]
    }
    
    var options: [Option] {[
        Tips.MaxDisplayCount(1),
        //Tips.IgnoresDisplayFrequency(true)
    ]}
}
