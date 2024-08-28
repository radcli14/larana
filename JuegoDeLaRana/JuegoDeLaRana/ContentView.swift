//
//  ContentView.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 8/27/24.
//

import SwiftUI
import RealityKit

struct ContentView : View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ARViewContainer()
                Header(for: geometry)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
            .overlay {
                OverlayView()
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
                    .foregroundColor(.accentColor)
                    .shadow(radius: Constants.headerShadowRadius)
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
        static let headerShadowRadius: CGFloat = 16
    }
    
    private var headerFontSize: CGFloat {
        UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
    }
}

struct ARViewContainer: UIViewRepresentable {
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = ARView(frame: .zero)

        // Create horizontal plane anchor for the content
        let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: SIMD2<Float>(0.2, 0.2)))

        // Load the La Rana scene
        if let larana = try? ModelEntity.loadModel(named: "Scene") {
            anchor.children.append(larana)
            if let laranaAnchor = larana.anchor {
                arView.scene.anchors.append(laranaAnchor)
            }
            if let coin = larana.findEntity(named: "Coin") {
                print("coin = \(coin)")
            }
        }
        
        // Add the horizontal plane anchor to the scene
        arView.scene.anchors.append(anchor)

        return arView
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
}

#Preview {
    ContentView()
}
