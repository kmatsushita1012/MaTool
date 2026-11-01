import Foundation

public enum StoreAdPlacement: String, Entity {
    case banner
    case interstitial

    public var creditCost: Int {
        switch self {
        case .banner: 1
        case .interstitial: 2
        }
    }
}

public struct PublicStore: DTO, Identifiable {
    public let id: Store.ID
    public let festivalId: Festival.ID
    public let name: String
    public let address: String
    public let coordinate: Coordinate
    public let businessHours: String
    @NullEncodable public var description: String?
    @NullEncodable public var bannerImagePath: String?
    @NullEncodable public var interstitialImagePath: String?
    public let updatedAt: Date

    public init(store: Store, hideImages: Bool) {
        id = store.id
        festivalId = store.festivalId
        name = store.name
        address = store.address
        coordinate = store.coordinate
        businessHours = store.businessHours
        description = store.description
        bannerImagePath = hideImages ? nil : store.bannerImagePath
        interstitialImagePath = hideImages ? nil : store.interstitialImagePath
        updatedAt = store.updatedAt
    }
}

public struct AdCandidate: DTO {
    public let storeId: Store.ID
    public let festivalId: Festival.ID
    public let placement: StoreAdPlacement
    public let imagePath: String
    public let updatedAt: Date
    public let impressionId: String
    public let impressionToken: String

    public init(storeId: Store.ID, festivalId: Festival.ID, placement: StoreAdPlacement, imagePath: String, updatedAt: Date, impressionId: String, impressionToken: String) {
        self.storeId = storeId
        self.festivalId = festivalId
        self.placement = placement
        self.imagePath = imagePath
        self.updatedAt = updatedAt
        self.impressionId = impressionId
        self.impressionToken = impressionToken
    }
}

public struct ImpressionReportRequest: DTO {
    public let impressionId: String
    public let impressionToken: String
    public init(impressionId: String, impressionToken: String) {
        self.impressionId = impressionId
        self.impressionToken = impressionToken
    }
}

public struct AdvertisementReportRequest: DTO {
    public let storeId: Store.ID
    @NullEncodable public var placement: StoreAdPlacement?
    public let reason: String
    public init(storeId: Store.ID, placement: StoreAdPlacement? = nil, reason: String) {
        self.storeId = storeId
        self.placement = placement
        self.reason = reason
    }
}
