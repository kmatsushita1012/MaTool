import Dependencies
import Shared

protocol PeriodDataFetcherProtocol: DataFetcher {
    func fetchAll(festivalID: Festival.ID, query: Query) async throws -> [Period]
    func fetch(_ id: Period.ID) async throws -> Period
    func update(_ period: Period) async throws -> Period
    func create(_ period: Period) async throws -> Period
    func delete(_ id: Period.ID) async throws
}

enum PeriodDataFetcherKey: DependencyKey {
    static let liveValue: PeriodDataFetcherProtocol = PeriodDataFetcher()
}

struct PeriodDataFetcher: PeriodDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) var client

    func fetchAll(festivalID: Festival.ID, query: Query) async throws -> [Period] {
        try await client.get(path: "/festivals/\(festivalID)/periods", query: query.queryItems)
    }

    func fetch(_ id: Period.ID) async throws -> Period {
        try await client.get(path: "/periods/\(id)")
    }

    func update(_ period: Period) async throws -> Period {
        try await client.put(path: "/periods/\(period.id)", body: period, accessToken: await getToken())
    }

    func create(_ period: Period) async throws -> Period {
        try await client.post(path: "/festivals/\(period.festivalId)/periods", body: period, accessToken: await getToken())
    }

    func delete(_ id: Period.ID) async throws {
        try await client.delete(path: "/periods/\(id)", accessToken: await getToken())
    }
}
