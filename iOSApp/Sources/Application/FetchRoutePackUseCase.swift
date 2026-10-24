import ComposableArchitecture
import Dependencies
import Shared

protocol FetchRoutePackUseCaseProtocol: Sendable {
    func callAsFunction(routeId: Route.ID) async throws -> RoutePack
}

struct FetchRoutePackUseCase: FetchRoutePackUseCaseProtocol {
    @Dependency(RouteDataFetcherKey.self) private var dataFetcher

    func callAsFunction(routeId: Route.ID) async throws -> RoutePack {
        try await dataFetcher.fetch(routeID: routeId)
    }
}

enum FetchRoutePackUseCaseKey: DependencyKey {
    static let liveValue: any FetchRoutePackUseCaseProtocol = FetchRoutePackUseCase()
}
