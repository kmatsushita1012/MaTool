import Foundation

public struct ImageUploadTarget: DTO {
    public enum Kind: String, Codable, Hashable, Sendable {
        case store, festival, district
    }

    public enum Variant: String, Codable, Hashable, Sendable {
        case banner, interstitial, light, dark
    }

    public let type: Kind
    public let id: String
    public let variant: Variant

    public init(type: Kind, id: String, variant: Variant) {
        self.type = type
        self.id = id
        self.variant = variant
    }
}

public struct ImageUploadURLRequest: DTO {
    public let target: ImageUploadTarget
    public let contentType: String

    public init(target: ImageUploadTarget, contentType: String) {
        self.target = target
        self.contentType = contentType
    }
}

public struct ImageUploadURLResponse: DTO {
    public let url: String
    public let path: String
    public let expiresAt: Date

    public init(url: String, path: String, expiresAt: Date) {
        self.url = url
        self.path = path
        self.expiresAt = expiresAt
    }
}
