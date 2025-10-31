//
//  District.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

// MARK: - District
public struct District: Entity{
    public let id: String
    public var name: String
    public let festivalId: String
    @NullEncodable public var description: String? = nil
    @NullEncodable public var base: Coordinate? = nil
    public var area: [Coordinate] = []
    @NullEncodable public  var imagePath:String? = nil
    public var performances: [Performance] = []
    public var visibility: Visibility
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case festivalId = "regionId"  // JSONのregionIdをfestivalIdにマッピング
        case description
        case base
        case area
        case imagePath
        case performances
        case visibility
    }
}

extension District: Identifiable {}

// MARK: - Performance
public struct Performance: Entity {
    public let id: String
    public var name: String = ""
    public var performer: String = ""
    @NullEncodable public var description: String?
    
    public init(
        id: String,
        name: String = "",
        performer: String = "",
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.performer = performer
        self.description = description
    }
}

extension Performance: Identifiable {}
