import ComposableArchitecture
import Dependencies
import Shared

protocol FetchRouteUseCaseProtocol: Sendable {
    func callAsFunction(districtId: District.ID, query: Query) async throws -> [Route]
}

struct FetchRouteUseCase: FetchRouteUseCaseProtocol {
    @Dependency(RouteDataFetcherKey.self) private var dataFetcher

    func callAsFunction(districtId: District.ID, query: Query) async throws -> [Route] {
        try await dataFetcher.fetchAll(districtID: districtId, query: query)
    }
}

enum FetchRouteUseCaseKey: DependencyKey {
    static let liveValue: any FetchRouteUseCaseProtocol = FetchRouteUseCase()
}
