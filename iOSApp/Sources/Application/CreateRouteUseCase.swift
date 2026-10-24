import ComposableArchitecture
import Dependencies
import Shared

protocol CreateRouteUseCaseProtocol: Sendable {
    func callAsFunction(
        districtId: District.ID,
        route: Route,
        points: [Point],
        passages: [RoutePassage],
        appState: Shared<AppState?>
    ) async throws -> RoutePack
}

struct CreateRouteUseCase: CreateRouteUseCaseProtocol {
    @Dependency(RouteDataFetcherKey.self) private var dataFetcher

    func callAsFunction(
        districtId: District.ID,
        route: Route,
        points: [Point],
        passages: [RoutePassage],
        appState: Shared<AppState?>
    ) async throws -> RoutePack {
        let context = captureRouteStateUpdateContext(appState)
        let response = try await dataFetcher.create(
            districtID: districtId,
            route: route,
            points: points,
            passages: passages
        )
        applyRoutePackResponse(response, context: context, to: appState)
        return response
    }
}

enum CreateRouteUseCaseKey: DependencyKey {
    static let liveValue: any CreateRouteUseCaseProtocol = CreateRouteUseCase()
}
