import Foundation

public struct StoreCreateRequest: DTO {
    public let name: String
    @NullEncodable public var address: String?
    @NullEncodable public var coordinate: Coordinate?
    public let businessHours: String
    @NullEncodable public var description: String?

    public init(name: String, address: String? = nil, coordinate: Coordinate? = nil, businessHours: String, description: String? = nil) {
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.businessHours = businessHours
        self.description = description
    }
}
