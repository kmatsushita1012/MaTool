//
//  District.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

import SQLiteData

// MARK: - District
public struct District: Entity, Identifiable {
    public let id: String
    public var name: String
    public let festivalId: Festival.ID
    public var order: Int
    public var group: String?
    @NullEncodable public var description: String?
    @Column(as: Coordinate.JSONRepresentation.self)
    @NullEncodable public var base: Coordinate?
    public var area: [Coordinate]
    @Column(as: ImagePath.JSONRepresentation.self)
    public var image: ImagePath
    public var visibility: Visibility
    public var isEditable: Bool
    
    public init(
        id: String,
        name: String,
        festivalId: String,
        order: Int = 0,
        group: String? = nil,
        description: String? = nil,
        base: Coordinate? = nil,
        area: [Coordinate] = [],
        image: ImagePath = .init(),
        visibility: Visibility = .all,
        isEditable: Bool = true
    ) {
        self.id = id
        self.name = name
        self.festivalId = festivalId
        self.order = order
        self.group = group
        self.description = description
        self.base = base
        self.area = area
        self.image = image
        self.visibility = visibility
        self.isEditable = isEditable
    }
}

// MARK: - Performance
public struct Performance: Entity {
    public let id: String
    public var name: String = ""
    public let districtId: District.ID
    public var performer: String = ""
    @NullEncodable public var description: String?
    
    public init(
        id: String,
        name: String = "",
        districtId: District.ID,
        performer: String = "",
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.districtId = districtId
        self.performer = performer
        self.description = description
    }
}

extension Performance: Identifiable {}
