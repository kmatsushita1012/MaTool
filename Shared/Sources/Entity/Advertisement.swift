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
