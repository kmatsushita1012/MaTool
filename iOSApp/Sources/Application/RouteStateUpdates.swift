import ComposableArchitecture
import Foundation
import Shared

struct RouteStateUpdateContext: Sendable {
    let sessionId: UUID?
    let districtRequestId: UUID?
}

func captureRouteStateUpdateContext(_ appState: Shared<AppState?>) -> RouteStateUpdateContext {
    appState.withLock { current in
        RouteStateUpdateContext(
            sessionId: current?.sessionId,
            districtRequestId: current?.districtState?.requestId
        )
    }
}

func applyRoutePackResponse(
    _ response: RoutePack,
    context: RouteStateUpdateContext,
    to appState: Shared<AppState?>
) {
    appState.withLock { current in
        guard let sessionId = context.sessionId,
              var updated = current,
              updated.sessionId == sessionId,
              updated.districtState?.requestId == context.districtRequestId,
              updated.districtState?.districtId == response.route.districtId else { return }
        updated.routeLoadRequestId = UUID()
        let currentPeriodIds = Set(updated.festivalState.periods.map(\.id))
        guard currentPeriodIds.contains(response.route.periodId) else {
            updated.districtState?.routes.removeAll { $0.id == response.route.id }
            if updated.routeState?.route.id == response.route.id {
                updated.routeState = nil
            }
            current = updated
            return
        }
        if let routeIndex = updated.districtState?.routes.firstIndex(where: { $0.id == response.route.id }) {
            updated.districtState?.routes[routeIndex] = response.route
        } else {
            updated.districtState?.routes.append(response.route)
        }
        updated.routeState = RouteState(response)
        current = updated
    }
}
