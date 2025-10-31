//
//  Region.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

public struct Region: Codable, Equatable, Identifiable, Hashable {
    public let id: String
    public var name: String
    public var subname: String
    @NullEncodable public var description: String?
    public var prefecture: String
    public var city: String
    public var base: Coordinate
    public var spans: [Span] = []
    public var milestones: [Information] = []
    @NullEncodable public var imagePath:String?
}
