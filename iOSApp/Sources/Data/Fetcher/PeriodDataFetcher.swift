import Dependencies
import Shared

protocol PeriodDataFetcherProtocol: DataFetcher {
    func fetchAll(festivalID: Festival.ID, query: Query) async throws -> [Period]
    func fetch(_ id: Period.ID) async throws -> Period
}

enum PeriodDataFetcherKey: DependencyKey {
    static let liveValue: PeriodDataFetcherProtocol = PeriodDataFetcher()
}

struct PeriodDataFetcher: PeriodDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) var client

    func fetchAll(festivalID: Festival.ID, query: Query) async throws -> [Period] {
        try await client.get(path: "/v2/festivals/\(festivalID)/periods", query: query.queryItems)
    }

    func fetch(_ id: Period.ID) async throws -> Period {
        try await client.get(path: "/v2/periods/\(id)")
    }
}
