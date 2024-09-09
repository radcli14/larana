//
//  OverlayView.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 8/27/24.
//

import SwiftUI

/// Overlay of the user controls and scoring displayed on the bottom of the screen
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
            if state == .loading {
                ProgressView()
                    .scaleEffect(Constants.progressViewScale)
            }
            Spacer()
            Text(state.rawValue)
                .font(.caption)
            HStack(alignment: .center, spacing: Constants.buttonSpacing) {
                resetAnchorButton
                scoreBoard
                moveTableButton
            }
            .padding(Constants.backgroundPadding)
            .background {
                RoundedRectangle(cornerRadius: Constants.backgroundRadius)
                    .foregroundColor(Color(UIColor.systemBackground).opacity(Constants.backgroundOpacity))
            }
        }
    }
    
    // MARK: - Scoreboard
    
    /// Displays the coint for the number of coins you have thrown, how many hit La Rana, and how many hit the target (its mouth)
    private var scoreBoard: some View {
        VStack {
            Text("Score")
                .font(.callout)
            HStack {
                scoreContent(text: "Throws", score: nThrows)
                scoreContent(text: "Hits", score: nHitsLaRana)
                scoreContent(text: "Targets", score: nHitsTarget)
            }
            .font(.caption)
        }
    }
    
    /// A stack of the scoring category and its integer value
    private func scoreContent(text: String, score: Int) -> some View {
        VStack {
            Text(text)
                .font(.caption2)
            Text(score.description)
                .font(.subheadline)
        }
        .frame(width: Constants.textContentWidth)
    }
    
    // MARK: - Buttons
     
    /// A button that responds to itself being active by becoming prominent, defaults to bordered
    @ViewBuilder
    private func OverlayButton(
        text: String,
        systemName: String? = nil,
        activeForState: GameState,
        action: @escaping () -> Void
    ) -> some View {
        if state == activeForState {
            Button(action: { action() }) {
                OverlayButtonContent(text: text, systemName: systemName)
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button(action: { action() }) {
                OverlayButtonContent(text: text, systemName: systemName)
            }
            .buttonStyle(.bordered)
        }
    }
    
    /// Content of the button that can be either an icon or a string.
    /// If its an icon, the string displays in its context menu.
    @ViewBuilder
    private func OverlayButtonContent(text: String, systemName: String?) -> some View {
        if let systemName {
            Image(systemName: systemName)
                .contextMenu {
                    Text("Tap to \(text)")
                }
        } else {
            Text(text)
                .frame(width: Constants.textContentWidth)
        }
    }
    
    /// The button that will make the table reset to the nearest/best anchor position
    private var resetAnchorButton: some View {
        OverlayButton(text: "Reset Anchor", systemName: "arrow.counterclockwise", activeForState: .resetting, action: { onTapReset() })
    }
    
    /// The button that will allow the user to drag the table to a new position
    private var moveTableButton: some View {
        OverlayButton(text: "Move Table", systemName: "arrow.up.and.down.and.arrow.left.and.right", activeForState: .move, action: { onTapMove() })
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let progressViewScale = 6.28
        static let buttonSpacing: CGFloat = 12
        static let textContentWidth: CGFloat = 64
        static let backgroundPadding: CGFloat = 8
        static let backgroundOpacity = 0.5
        static let backgroundRadius: CGFloat = 16
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
