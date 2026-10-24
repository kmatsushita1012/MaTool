import Dependencies

protocol DataFetcher: Sendable {}

extension DataFetcher {
    func getToken() async -> String? {
        @Dependency(AuthServiceKey.self) var authService
        return await authService.getAccessToken()
    }
}

enum Query: Sendable, Equatable {
    case all
    case year(Int)
    case latest

    var queryItems: [String: Any] {
        switch self {
        case .all:
            [:]
        case .year(let year):
            ["year": year]
        case .latest:
            ["year": "latest"]
        }
    }
}
