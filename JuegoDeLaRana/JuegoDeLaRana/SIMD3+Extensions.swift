//
//  SIMD3+Extensions.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 9/11/24.
//

import Foundation
import simd

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
    
    func rotatedFrom(_ transformMatrix: float4x4) -> SIMD3<Float> {
        let inWorldFrame = transformMatrix * SIMD4<Float>(x, y, z, 0.0)
        return SIMD3<Float>(inWorldFrame.x, inWorldFrame.y, inWorldFrame.z)
    }
    
    func rotatedTo(_ transformMatrix: float4x4) -> SIMD3<Float> {
        let inLocalFrame = transformMatrix.inverse * SIMD4<Float>(x, y, z, 0.0)
        return SIMD3<Float>(inLocalFrame.x, inLocalFrame.y, inLocalFrame.z)
    }
    
    var csv: String {
        "\(x), \(y), \(z)"
    }
    
    static func random(in range: ClosedRange<Float>) -> SIMD3<Float> {
        SIMD3<Float>(Float.random(in: range), Float.random(in: range), Float.random(in: range))
    }
}
