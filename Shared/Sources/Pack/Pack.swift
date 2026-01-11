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

public struct DistrictPack: Pack {
    public let district: District
    public let performances: [Performance]
    
    public init(district: District, performances: [Performance]){
        self.district = district
        self.performances = performances
    }
}

public struct DistrictCreateForm: Pack {
    public let name: String
    public let email: String
    
    public init(name: String, email: String) {
        self.name = name
        self.email = email
    }
}
