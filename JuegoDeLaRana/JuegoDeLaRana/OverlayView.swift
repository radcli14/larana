//
//  OverlayView.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 8/27/24.
//

import SwiftUI

/// Overlay of the user controls and scoring displayed on the bottom of the screen
/// - Parameters:
///   - state: State of the game, such as `.loading`, `.resetting`, `.play`, `.move`, ...
///   - nThrows: Number of coins that the user has tossed
///   - nHitsLaRana: Number of coins that have hit the frog statue
///   - nHitsTarget: Number of coins that have gone in the frog's mouth
///   - onTapReset: Callback when the user taps the reset button
///   - onTapMove: Callback when the user taps the move button
struct OverlayView: View {
    let state: GameState
    let nThrows: Int
    let nHitsLaRana: Int
    let nHitsTarget: Int
    let onTapReset: () -> Void
    let onTapMove: () -> Void

    // State variables for the animation for changes in state
    @State private var stateDisplayPadding: CGFloat = Constants.stateDisplayDefaultPadding
    @State private var stateDisplayFontStyle: Font = .caption
    @State private var stateDisplayTextColor: Color = .primary
    
    var body: some View {
        VStack {
            Spacer()
            if state == .loading {
                ProgressView()
                    .scaleEffect(Constants.progressViewScale)
            }
            Spacer()
            stateDisplay
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
    
    // MARK: - State
    
    private var stateDisplay: some View {
        Text(state.rawValue)
            .multilineTextAlignment(.center)
            .padding(stateDisplayPadding)
            .font(stateDisplayFontStyle)
            .foregroundColor(stateDisplayTextColor)
            .onChange(of: state) {
                animateStateChange()
            }
    }
    
    private func animateStateChange() {
        // Before animation, reset modifiers to defaults
        stateDisplayPadding = Constants.stateDisplayDefaultPadding
        stateDisplayFontStyle = .caption
        stateDisplayTextColor = .primary
        
        // After a delay, grow to emphasize the state description text
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Constants.durationForFade) {
            withAnimation(.easeInOut(duration: Constants.durationForFade)) {
                // Increase size and change color
                stateDisplayPadding = Constants.stateDisplayAnimatePadding
                stateDisplayFontStyle = .headline
                stateDisplayTextColor = .accentColor
            }
        }

        // Return to original size and color after a delay
        let deadline = DispatchTime.now() + 2*Constants.durationForFade + Constants.durationForLargeText
        DispatchQueue.main.asyncAfter(deadline: deadline) {
            withAnimation(.easeInOut(duration: Constants.durationForFade)) {
                stateDisplayPadding = Constants.stateDisplayDefaultPadding
                stateDisplayFontStyle = .caption
                stateDisplayTextColor = .primary
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
        static let stateDisplayDefaultPadding: CGFloat = 0
        static let stateDisplayAnimatePadding: CGFloat = 24
        static let durationForLargeText = 1.69
        static let durationForFade = 0.69
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
