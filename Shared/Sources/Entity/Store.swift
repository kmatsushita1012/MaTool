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

}

public enum ModerationStatus: String, Entity {
    case approved
    case suspended
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
