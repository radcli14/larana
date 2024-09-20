//
//  Splash.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 9/20/24.
//

import SwiftUI

struct Splash: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(decorative: "Splash")
                    .resizable()
                    .ignoresSafeArea()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                
                VStack {
                    Text("Juego de la Rana")
                        .foregroundColor(.white)
                        .frame(maxWidth: Constants.maxHeaderWidth)
                        .padding(.top, Constants.headerTopPadding)
                        .font(.custom(Constants.headerFontName, size: headerFontSize))
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }
    
    private var headerFontSize: CGFloat {
        UIFont.preferredFont(forTextStyle: .title3).pointSize
    }
    
    private struct Constants {
        static let maxHeaderWidth: CGFloat = 420
        static let headerFontName = "Moderna"
        static let headerTopPadding: CGFloat = 56
    }
}

#Preview {
    Splash()
}
