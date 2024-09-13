//
//  AudioResources.swift
//  JuegoDeLaRana
//
//  Created by Eliott Radcliffe on 9/12/24.
//

import Foundation
import RealityKit

/// Initializes resources given a file naming convention of `"\(prefix)\(k).mp3"`
private func initResources(for prefix: String, quantity: Int) -> [AudioFileResource] {
    var result = [AudioFileResource]()
    for k in 0 ..< quantity {
        if let resource = try? AudioFileResource.load(named: "\(prefix)\(k).mp3") {
            result.append(resource)
        }
    }
    return result
}

/// Stores sound effects for different types of `CoinHit`
struct AudioResources {
    var tosses = [AudioFileResource]()
    var shows = [AudioFileResource]()
    var hides = [AudioFileResource]()
    var targets = [AudioFileResource]()
    var turfs = [AudioFileResource]()
    var misses = [AudioFileResource]()
    
    init() {
        tosses = initResources(for: "throw", quantity: 8)
        shows = initResources(for: "showTable", quantity: 5)
        hides = initResources(for: "hideTable", quantity: 5)
        targets = initResources(for: "target", quantity: 4)
        turfs = initResources(for: "turf", quantity: 2)
        misses = initResources(for: "miss", quantity: 3)
    }
    
    /// Provides sound effects for different types of `CoinHit`
    func getResource(for hit: CoinHit) -> AudioFileResource? {
        if hit == .hole || hit == .larana {
            return targets.randomElement()
        } else if hit == .turf {
            return turfs.randomElement()
        } else {
            return misses.randomElement()
        }
    }
}
