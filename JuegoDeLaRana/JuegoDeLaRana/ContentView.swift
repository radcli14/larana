//
//  ContentView.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 8/27/24.
//

import SwiftUI
import RealityKit
import TipKit

struct ContentView : View {
    @ObservedObject var viewModel: LaRanaViewModel = LaRanaViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ARViewContainer(viewModel: viewModel)
                Header(for: geometry)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
            .overlay {
                if viewModel.state == .new || viewModel.state == .loading {
                    Splash()
                } else {
                    OverlayView(
                        state: viewModel.state,
                        nThrows: viewModel.nTossed,
                        nHitsLaRana: viewModel.nHitLaRana,
                        nHitsTarget: viewModel.nHitTarget,
                        onTapReset: {
                            withAnimation {
                                viewModel.resetAnchor()
                            }
                        },
                        onTapMove: {
                            withAnimation {
                                viewModel.toggleMove()
                            }
                        }
                    )
                }
            }
        }
        .task {
            // Configure and load your tips at app launch.
            do {
                try Tips.resetDatastore()
                try Tips.configure([
                    .displayFrequency(.immediate),
                    .datastoreLocation(.applicationDefault),
                ])
            }
            catch {
                // Handle TipKit errors
                print("Error initializing TipKit \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Header
    
    @ViewBuilder
    private func Header(for geometry: GeometryProxy) -> some View {
        Text("Juego de la Rana")
            .frame(maxWidth: Constants.maxHeaderWidth)
            .font(.custom(Constants.headerFontName, size: headerFontSize))
            .padding(.top, topPadding(for: geometry.safeAreaInsets.top))
            .padding(.bottom, Constants.headerBottomPadding)
            .background {
                RoundedRectangle(cornerRadius: Constants.backgroundCornerRadius)
                    .foregroundColor(Color(UIColor.systemBackground).opacity(Constants.backgroundOpacity))
            }
    }
    
    private func topPadding(for inset: CGFloat) -> CGFloat {
        inset > Constants.headerBottomPadding ? inset : Constants.headerBottomPadding
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let maxHeaderWidth: CGFloat = 420
        static let headerFontName = "Moderna"
        static let headerTopPadding: CGFloat = 56
        static let headerBottomPadding: CGFloat = 12
        static let backgroundCornerRadius: CGFloat = 56
        static let backgroundOpacity = 0.5
    }
    
    private var headerFontSize: CGFloat {
        UIFont.preferredFont(forTextStyle: .title3).pointSize
    }
}


#Preview {
    ContentView()
}
