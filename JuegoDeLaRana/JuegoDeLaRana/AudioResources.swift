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
        for k in 0 ..< 7 {
            if let resource = try? AudioFileResource.load(named: "target\(k).mp3") {
                targets.append(resource)
            }
        }
        for k in 0 ..< 5 {
            if let resource = try? AudioFileResource.load(named: "miss\(k).mp3") {
                misses.append(resource)
            }
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
