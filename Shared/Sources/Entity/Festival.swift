//
//  Festival.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

import Foundation
import SQLiteData

@Table public struct Festival: Entity, Identifiable {
    public let id: String
    public var name: String
    public var subname: String
    @NullEncodable public var description: String?
    public var prefecture: String
    public var city: String
    @Column(as: Coordinate.JSONRepresentation.self)
    public var base: Coordinate
    @Column(as: ImagePath.JSONRepresentation.self)
    public var image: ImagePath

    public init(
        id: String,
        name: String,
        subname: String,
        description: String? = nil,
        prefecture: String = "",
        city: String = "",
        base: Coordinate,
        image: ImagePath = .init()
    ) {
        self.id = id
        self.name = name
        self.subname = subname
        self.description = description
        self.prefecture = prefecture
        self.city = city
        self.base = base
        self.image = image
    }
}


// MARK: - Checkpoint
@Table public struct Checkpoint: Entity, Identifiable {
    public let id: String
    public let festivalId: Festival.ID
    public var name: String
    @NullEncodable public var description: String? = nil
    
    public init(id: String, name: String = "", festivalId:Festival.ID, description: String? = nil) {
        self.id = id
        self.name = name
        self.festivalId = festivalId
        self.description = description
    }
}

// MARK: - HazardSection
public struct HazardSection: Entity, Identifiable {
    public let id: String
    public var title: String
    public let festivalId: Festival.ID
    @Column(as: [Coordinate].JSONRepresentation.self)
    public var coordinates: [Coordinate]
    
    public init(id: String, title: String = "", festivalId: Festival.ID, coordinates: [Coordinate] = []) {
        self.id = id
        self.title = title
        self.festivalId = festivalId
        self.coordinates = coordinates
    }
}
