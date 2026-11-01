import Foundation

public struct Store: Entity, Identifiable {
    public let id: String
    public let festivalId: Festival.ID
    public let ownerId: String
    public let purchaseAccountToken: UUID
    public var name: String
    public var address: String
    public var coordinate: Coordinate
    public var businessHours: String
    @NullEncodable public var description: String?
    @NullEncodable public var bannerImagePath: String?
    @NullEncodable public var interstitialImagePath: String?
    public var ownerPaused: Bool
    public let moderationStatus: ModerationStatus
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        festivalId: Festival.ID,
        ownerId: String,
        purchaseAccountToken: UUID,
        name: String,
        address: String,
        coordinate: Coordinate,
        businessHours: String,
        description: String? = nil,
        bannerImagePath: String? = nil,
        interstitialImagePath: String? = nil,
        ownerPaused: Bool = false,
        moderationStatus: ModerationStatus = .approved,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.festivalId = festivalId
        self.ownerId = ownerId
        self.purchaseAccountToken = purchaseAccountToken
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.businessHours = businessHours
        self.description = description
        self.bannerImagePath = bannerImagePath
        self.interstitialImagePath = interstitialImagePath
        self.ownerPaused = ownerPaused
        self.moderationStatus = moderationStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, festivalId, ownerId, purchaseAccountToken
        case name, address, coordinate, businessHours, description
        case bannerImagePath, interstitialImagePath, ownerPaused
        case moderationStatus, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        festivalId = try container.decode(String.self, forKey: .festivalId)
        ownerId = try container.decode(String.self, forKey: .ownerId)
        purchaseAccountToken = try container.decode(UUID.self, forKey: .purchaseAccountToken)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        coordinate = try container.decode(Coordinate.self, forKey: .coordinate)
        businessHours = try container.decode(String.self, forKey: .businessHours)
        _description = try container.decode(NullEncodable<String>.self, forKey: .description)
        _bannerImagePath = try container.decode(NullEncodable<String>.self, forKey: .bannerImagePath)
        _interstitialImagePath = try container.decode(NullEncodable<String>.self, forKey: .interstitialImagePath)
        ownerPaused = try container.decode(Bool.self, forKey: .ownerPaused)
        moderationStatus = try container.decode(ModerationStatus.self, forKey: .moderationStatus)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(festivalId, forKey: .festivalId)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(purchaseAccountToken, forKey: .purchaseAccountToken)
        try container.encode(name, forKey: .name)
        try container.encode(address, forKey: .address)
        try container.encode(coordinate, forKey: .coordinate)
        try container.encode(businessHours, forKey: .businessHours)
        try container.encode(_description, forKey: .description)
        try container.encode(_bannerImagePath, forKey: .bannerImagePath)
        try container.encode(_interstitialImagePath, forKey: .interstitialImagePath)
        try container.encode(ownerPaused, forKey: .ownerPaused)
        try container.encode(moderationStatus, forKey: .moderationStatus)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

public enum ModerationStatus: String, Entity {
    case approved
    case suspended
}

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

public struct StoreOwnerReference: Entity, Identifiable {
    public let storeId: Store.ID
    public let festivalId: Festival.ID
    public var id: String { storeId }

    public init(storeId: Store.ID, festivalId: Festival.ID) {
        self.storeId = storeId
        self.festivalId = festivalId
    }
}
