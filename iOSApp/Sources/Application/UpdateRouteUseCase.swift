import ComposableArchitecture
import Dependencies
import Shared

protocol UpdateRouteUseCaseProtocol: Sendable {
    func callAsFunction(
        _ route: Route,
        points: [Point],
        passages: [RoutePassage],
        appState: Shared<AppState?>
    ) async throws -> RoutePack
}

struct UpdateRouteUseCase: UpdateRouteUseCaseProtocol {
    @Dependency(RouteDataFetcherKey.self) private var dataFetcher

    func callAsFunction(
        _ route: Route,
        points: [Point],
        passages: [RoutePassage],
        appState: Shared<AppState?>
    ) async throws -> RoutePack {
        let context = captureRouteStateUpdateContext(appState)
        let response = try await dataFetcher.update(route, points: points, passages: passages)
        applyRoutePackResponse(response, context: context, to: appState)
        return response
    }
}

enum UpdateRouteUseCaseKey: DependencyKey {
    static let liveValue: any UpdateRouteUseCaseProtocol = UpdateRouteUseCase()
}
