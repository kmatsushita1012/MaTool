import Shared

public enum PublicMapContent: Equatable, Hashable, Identifiable {
    case locations(Festival)
    case route(District)

    public var id: String {
        switch self {
        case .locations(let festival): festival.id
        case .route(let district): district.id
        }
    }

    public var name: String {
        switch self {
        case .locations(let festival): festival.name
        case .route(let district): district.name
        }
    }

    public var text: String {
        switch self {
        case .locations: "現在地一覧"
        case .route(let district): district.name
        }
    }
}

public enum FestivalInfoDisplayMode: String, CaseIterable, Equatable, Sendable {
    case festival = "祭紹介"
    case districts = "町一覧"
}

public enum HomeTab: Equatable, Identifiable, CaseIterable, Sendable {
    case map
    case info
    case account

    public var id: Self { self }

    public static var allCases: [Self] { [.map, .info, .account] }
}

public enum RouteEditMode: Equatable, Sendable {
    case create
    case update
    case preview
}

public enum RouteEditTab: Equatable, Sendable {
    case info
    case edit
    case `public`
}

public enum RouteEditOperation: Equatable, Sendable {
    case add
    case move(Int)
    case insert(Int)
}
