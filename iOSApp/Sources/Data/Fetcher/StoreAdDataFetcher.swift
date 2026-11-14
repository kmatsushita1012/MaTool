import Dependencies
import Shared

extension DependencyValues {
    var storeAdDataFetcher: any StoreAdDataFetcherProtocol {
        get { self[StoreAdDataFetcherKey.self] }
        set { self[StoreAdDataFetcherKey.self] = newValue }
    }
}

protocol StoreAdDataFetcherProtocol: DataFetcher {
    func nextBanner(festivalId: Festival.ID) async throws -> AdCandidate?
    func reportImpression(_ request: ImpressionReportRequest) async throws
}

struct StoreAdDataFetcher: StoreAdDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) private var client

    func nextBanner(festivalId: Festival.ID) async throws -> AdCandidate? {
        try await client.get(
            path: "/festivals/\(festivalId)/advertisements/next",
            query: ["placement": StoreAdPlacement.banner.rawValue],
            accessToken: nil,
            isCache: false
        )
    }

    func reportImpression(_ request: ImpressionReportRequest) async throws {
        try await client.post(path: "/advertisements/impressions", body: request, accessToken: nil)
    }
}

enum StoreAdDataFetcherKey: DependencyKey {
    static let liveValue: any StoreAdDataFetcherProtocol = StoreAdDataFetcher()
}
