//
//  OverlayView.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 8/27/24.
//

import SwiftUI

struct OverlayView: View {
    var body: some View {
        let fontName = "Moderna"
        let fontSize = UIFont.preferredFont(forTextStyle: .title1).pointSize
        
        VStack(alignment: .leading) {
            Text("Juego de la Rana")
                .font(.custom(fontName, size: fontSize))
            Spacer()
        }
        .padding()
    }
}

#Preview {
    OverlayView()
}
