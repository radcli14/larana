//
//  CoinHit.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 9/18/24.
//

import Foundation

enum CoinHit: Int {
    case ground = 0
    case turf = 1
    case larana = 2
    case hole = 3
}

struct CoinHitAlert {
    var announcement: String = ""
    var color: String = ""
    
    init(for hit: CoinHit) {
        announcement = hit == .hole ? success : hit == .larana ? close : hit == .turf ? turf : miss
        color = hit == .hole ? "green" : hit == .larana ? "blue" : hit == .turf ? "white" : "red"
    }
    
    var success: String {
        ["¡ÉXITO!", "¡EN EL HOYO!", "¡GOOOOOOL!", "¡ENHORABUENA!", "¡MUY BIEN!", "¡BUENO!", "¡BUENISIMO!"].randomElement() ?? "¡EXITO!"
    }
    
    var close: String {
        ["¡cerca!", "¡casi!", "¡bien!", "¡mejor!", "¡buen intento!", "¡vale!"].randomElement() ?? "¡cerca!"
    }
    
    var turf: String {
        ["sigue intentándolo", "en la mesa", "en el césped", "al lado"].randomElement() ?? "sigue intentándolo"
    }
    
    var miss: String {
        ["fallaste", "fuera", "lejos", "malo", "peor", "no soporto"].randomElement() ?? "fallaste"
    }
}
