import ComposableArchitecture
import Foundation
import Shared

struct DistrictStateLoadContext: Sendable {
    let requestId: UUID
    let sessionId: UUID?
}

func beginDistrictStateLoad(in appState: Shared<AppState?>) -> DistrictStateLoadContext {
    let requestId = UUID()
    let sessionId = appState.withLock { current -> UUID? in
        guard var updated = current else { return nil }
        updated.districtLoadRequestId = requestId
        updated.routeLoadRequestId = UUID()
        updated.districtState = nil
        updated.routeState = nil
        current = updated
        return updated.sessionId
    }
    return DistrictStateLoadContext(requestId: requestId, sessionId: sessionId)
}

@discardableResult
func applyDistrictStateResponse(
    _ response: LaunchDistrictPack,
    districtId: District.ID,
    context: DistrictStateLoadContext,
    to appState: Shared<AppState?>
) -> Bool {
    appState.withLock { current in
        guard var updated = current,
              updated.sessionId == context.sessionId,
              updated.districtLoadRequestId == context.requestId,
              updated.district(id: districtId) != nil else { return false }
        updated.districtState = DistrictState(
            districtId: districtId,
            requestId: context.requestId,
            pack: response,
            currentPeriodIds: Set(updated.festivalState.periods.map(\.id))
        )
        if let routeId = response.currentRouteId,
           let route = updated.districtState?.route(id: routeId) {
            updated.routeState = RouteState(route: route, points: response.points, passages: response.passages)
        }
        current = updated
        return true
    }
}

func clearDistrictState(in appState: Shared<AppState?>) {
    appState.withLock { current in
        guard var updated = current else { return }
        updated.districtLoadRequestId = UUID()
        updated.routeLoadRequestId = UUID()
        updated.districtState = nil
        updated.routeState = nil
        current = updated
    }
}
