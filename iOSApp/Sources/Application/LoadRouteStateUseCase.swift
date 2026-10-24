import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol LoadRouteStateUseCaseProtocol: Sendable {
    func callAsFunction(routeId: Route.ID, appState: Shared<AppState?>) async throws -> RoutePack
}

struct LoadRouteStateUseCase: LoadRouteStateUseCaseProtocol {
    @Dependency(RouteDataFetcherKey.self) private var dataFetcher

    func callAsFunction(routeId: Route.ID, appState: Shared<AppState?>) async throws -> RoutePack {
        let requestId = UUID()
        let context = appState.withLock { current -> (sessionId: UUID, districtRequestId: UUID, districtId: District.ID)? in
            guard var updated = current,
                  let districtState = updated.districtState,
                  districtState.routes.contains(where: { $0.id == routeId }) else { return nil }
            updated.routeLoadRequestId = requestId
            current = updated
            return (updated.sessionId, districtState.requestId, districtState.districtId)
        }
        let response = try await dataFetcher.fetch(routeID: routeId)
        appState.withLock { current in
            guard let context,
                  var updated = current,
                  updated.sessionId == context.sessionId,
                  updated.routeLoadRequestId == requestId,
                  updated.districtState?.requestId == context.districtRequestId,
                  updated.districtState?.districtId == context.districtId,
                  updated.districtState?.districtId == response.route.districtId,
                  updated.festivalState.periods.contains(where: { $0.id == response.route.periodId }),
                  let routeIndex = updated.districtState?.routes.firstIndex(where: { $0.id == response.route.id }) else {
                return
            }
            updated.districtState?.routes[routeIndex] = response.route
            updated.routeState = RouteState(response)
            current = updated
        }
        return response
    }
}

enum LoadRouteStateUseCaseKey: DependencyKey {
    static let liveValue: any LoadRouteStateUseCaseProtocol = LoadRouteStateUseCase()
}
