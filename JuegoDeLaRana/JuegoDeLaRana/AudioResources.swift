//
//  AudioResources.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 9/12/24.
//

import Foundation
import RealityKit

struct AudioResources {
    var targets = [AudioFileResource]()
    var misses = [AudioFileResource]()
    
    init() {
        if let resource = try? AudioFileResource.load(named: "target0.mp3") {
            targets.append(resource)
        }
        if let resource = try? AudioFileResource.load(named: "miss0.mp3") {
            misses.append(resource)
        }
    }
    
    func getResource(for hit: CoinHit) -> AudioFileResource? {
        if hit == .hole || hit == .larana {
            return targets.randomElement()
        } else {
            return misses.randomElement()
        }
    }
}
