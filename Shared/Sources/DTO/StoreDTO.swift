import Foundation

public struct StoreCreateRequest: DTO {
    public let name: String
    public let address: String
    public let coordinate: Coordinate
    public let businessHours: String
    @NullEncodable public var description: String?

    public init(name: String, address: String, coordinate: Coordinate, businessHours: String, description: String? = nil) {
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.businessHours = businessHours
        self.description = description
    }
}
