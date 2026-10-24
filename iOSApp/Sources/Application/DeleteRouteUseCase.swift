import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol DeleteRouteUseCaseProtocol: Sendable {
    func callAsFunction(routeId: Route.ID, appState: Shared<AppState?>) async throws
}

struct DeleteRouteUseCase: DeleteRouteUseCaseProtocol {
    @Dependency(RouteDataFetcherKey.self) private var dataFetcher

    func callAsFunction(routeId: Route.ID, appState: Shared<AppState?>) async throws {
        let context = appState.withLock { ($0?.sessionId, $0?.districtState?.requestId) }
        try await dataFetcher.delete(routeId)
        appState.withLock { current in
            guard let sessionId = context.0,
                  var updated = current,
                  updated.sessionId == sessionId,
                  updated.districtState?.requestId == context.1 else { return }
            updated.routeLoadRequestId = UUID()
            updated.districtState?.routes.removeAll { $0.id == routeId }
            if updated.routeState?.route.id == routeId {
                updated.routeState = nil
            }
            current = updated
        }
    }
}

enum DeleteRouteUseCaseKey: DependencyKey {
    static let liveValue: any DeleteRouteUseCaseProtocol = DeleteRouteUseCase()
}
