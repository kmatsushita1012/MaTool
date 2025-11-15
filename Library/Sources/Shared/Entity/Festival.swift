//
//  Festival.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

public struct Festival: Entity {
    public let id: String
    public var name: String
    public var subname: String
    @NullEncodable public var description: String?
    public var prefecture: String
    public var city: String
    public var base: Coordinate
    public var spans: [Span]
    public var milestones: [Information]
    @NullEncodable public var imagePath:String?
    
    public init(id: String, name: String, subname: String, description: String? = nil, prefecture: String, city: String, base: Coordinate, spans: [Span] = [], milestones: [Information] = [], imagePath: String? = nil) {
        self.id = id
        self.name = name
        self.subname = subname
        self.description = description
        self.prefecture = prefecture
        self.city = city
        self.base = base
        self.spans = spans
        self.milestones = milestones
        self.imagePath = imagePath
    }
    
}

extension Festival: Identifiable {}
