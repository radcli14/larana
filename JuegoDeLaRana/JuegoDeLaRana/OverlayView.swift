//
//  OverlayView.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 8/27/24.
//

import SwiftUI

struct OverlayView: View {
    let state: GameState
    let nThrows: Int
    let nHitsLaRana: Int
    let nHitsTarget: Int
    let onTapReset: () -> Void
    let onTapMove: () -> Void

    var body: some View {
        VStack {
            Spacer()
            scoreBoard
            HStack(alignment: .center, spacing: Constants.buttonSpacing) {
                resetAnchorButton
                moveTableButton
            }
        }
    }
    
    // MARK: - Scoreboard
    
    private var scoreBoard: some View {
        VStack {
            Text("Score")
                .font(.callout)
            HStack {
                Text("Throws: \(nThrows)")
                Text("Hit La Rana: \(nHitsLaRana)")
                Text("In the Hole: \(nHitsTarget)")
            }
            .font(.caption)
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .foregroundColor(Color(UIColor.systemBackground))
        }
    }
    
    // MARK: - Buttons
     
    @ViewBuilder
    private func OverlayButton(text: String, activeForState: GameState, action: @escaping () -> Void) -> some View {
        if state == activeForState {
            Button(action: { action() }) {
                Text(text)
            }
            .frame(width: Constants.buttonWidth)
            .buttonStyle(.borderedProminent)
        } else {
            Button(action: { action() }) {
                Text(text)
            }
            .frame(width: Constants.buttonWidth)
            .buttonStyle(.bordered)
        }
        
    }
    
    private var resetAnchorButton: some View {
        OverlayButton(text: "Reset\nAnchor", activeForState: .resetting, action: { onTapReset() })
    }
    
    private var moveTableButton: some View {
        OverlayButton(text: "Move\nTable", activeForState: .move, action: { onTapMove() })
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let buttonSpacing: CGFloat = 0
        static let buttonWidth: CGFloat = 96
    }
}

#Preview {
    OverlayView(
        state: .move,
        nThrows: 0,
        nHitsLaRana: 0,
        nHitsTarget: 0,
        onTapReset: {},
        onTapMove: {}
    )
}
