import Dependencies

protocol DataFetcher: Sendable {}

extension DataFetcher {
    func getToken() async -> String? {
        @Dependency(\.authProvider) var authProvider
        return try? await authProvider.getTokens()
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
