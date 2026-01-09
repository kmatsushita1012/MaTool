//
//  Pack.swift
//  matool-shared
//
//  Created by 松下和也 on 2026/01/09.
//

public struct FestivalPack: Pack {
    public let festival: Festival
    public let checkpoints: [Checkpoint]
    public let hazardSections: [HazardSection]
    
    public init(festival: Festival, checkpoints: [Checkpoint], hazardSections: [HazardSection]) {
        self.festival = festival
        self.checkpoints = checkpoints
        self.hazardSections = hazardSections
    }
}
