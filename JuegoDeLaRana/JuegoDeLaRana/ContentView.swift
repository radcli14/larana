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
    @ObservedObject var viewModel: LaRanaViewModel
    @State var cameraMode = ARView.CameraMode.nonAR
    
    init(viewModel: LaRanaViewModel = LaRanaViewModel()) {
        self.viewModel = viewModel
        cameraMode = viewModel.cameraMode
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ARViewContainer(viewModel: viewModel)
                VStack {
                    Header(for: geometry)
                    Picker("Mode", selection: $cameraMode) {
                        Text("VR").tag(ARView.CameraMode.nonAR).font(.title)
                        Text("AR").tag(ARView.CameraMode.ar).font(.title)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: Constants.pickerWidth)
                    .onChange(of: cameraMode) {
                        // Setting the cameraMode in the viewModel will make it try to activate the new mode in the entities
                        viewModel.cameraMode = cameraMode
                        
                        // Make sure the state change worked, if not, reset to what the viewModel gets from the entities
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            cameraMode = viewModel.cameraMode
                        }
                    }
                }
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
                try Tips.resetDatastore() // For debugging to make sure the tips always are displayed
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
        static let pickerWidth: CGFloat = 96
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
