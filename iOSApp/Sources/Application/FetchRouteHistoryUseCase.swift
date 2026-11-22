import Dependencies
import Shared

protocol FetchRouteHistoryUseCaseProtocol: Sendable {
    func callAsFunction(districtId: District.ID, editionId: Edition.ID) async throws -> [EditionRouteHistory]
}

struct FetchRouteHistoryUseCase: FetchRouteHistoryUseCaseProtocol {
    @Dependency(RouteDataFetcherKey.self) private var routeDataFetcher

    func callAsFunction(districtId: District.ID, editionId: Edition.ID) async throws -> [EditionRouteHistory] {
        try await routeDataFetcher.fetchHistory(districtID: districtId, before: editionId)
    }
}

enum FetchRouteHistoryUseCaseKey: DependencyKey {
    static let liveValue: any FetchRouteHistoryUseCaseProtocol = FetchRouteHistoryUseCase()
}
