//
//  SIMD3+Extensions.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 9/11/24.
//

import Foundation

extension SIMD3<Float> {
    var magnitudeSquared: Float {
        x*x + y*y + z*z
    }
    
    var magnitude: Float {
        sqrt(magnitudeSquared)
    }
    
    var normalized: SIMD3<Float> {
        magnitude > 0 ? self / magnitude : SIMD3<Float>()
    }
    
    func dot(_ other: SIMD3<Float>) -> Float {
        x*other.x + y*other.y + z*other.z
    }
}
