//
//  Festival.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

import Foundation

public struct Festival: Entity {
    public let id: String
    public var name: String
    public var subname: String
    @NullEncodable public var description: String?
    public var prefecture: String
    public var city: String
    public var base: Coordinate
    public var checkpoints: [Checkpoint]
    public var hazardSections: [HazardSection]
    @NullEncodable public var imagePath: String?

    public init(
        id: String,
        name: String,
        subname: String,
        description: String? = nil,
        prefecture: String,
        city: String,
        base: Coordinate,
        checkpoints: [Checkpoint] = [],
        hazardSection: [HazardSection] = [],
        imagePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.subname = subname
        self.description = description
        self.prefecture = prefecture
        self.city = city
        self.base = base
        self.checkpoints = checkpoints
        self.hazardSections = hazardSection
        self.imagePath = imagePath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id         = try container.decode(String.self, forKey: .id)
        self.name       = try container.decode(String.self, forKey: .name)
        self.subname    = try container.decode(String.self, forKey: .subname)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.prefecture = try container.decode(String.self, forKey: .prefecture)
        self.city       = try container.decode(String.self, forKey: .city)
        self.base       = try container.decode(Coordinate.self, forKey: .base)
        let legacy = try? decoder.container(keyedBy: LegacyKeys.self)
        self.checkpoints =
            try container.decodeIfPresent([Checkpoint].self, forKey: .checkpoints)
            ?? (try legacy?.decodeIfPresent([Checkpoint].self, forKey: .milestones))
            ?? []
        
        self.hazardSections = try container.decodeIfPresent([HazardSection].self, forKey: .hazardSections) ?? []

        self.imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case subname
        case description
        case prefecture
        case city
        case base
        case checkpoints
        case hazardSections
        case imagePath
    }

    private enum LegacyKeys: String, CodingKey {
        case milestones
    }
}

extension Festival: Identifiable {}

// MARK: - Checkpoint
public struct Checkpoint: Entity, Identifiable {
    public let id: String
    public var name: String = ""
    @NullEncodable public var description: String? = nil
    
    public init(id: String, name: String = "", description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }
}

// MARK: - HazardSection
public struct HazardSection: Entity {
    public let id: String
    public var title: String
    public var coordinates: [Coordinate]
    
    public init(id: String, title: String, coordinates: [Coordinate]) {
        self.id = id
        self.title = title
        self.coordinates = coordinates
    }
}

extension HazardSection: Identifiable {}
