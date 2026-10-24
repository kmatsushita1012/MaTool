import ComposableArchitecture
import Foundation
import Shared

func applyPeriodResponse(_ response: Period, sessionId: UUID?, to appState: Shared<AppState?>) {
    appState.withLock { current in
        guard let sessionId,
              var updated = current,
              updated.sessionId == sessionId,
              updated.festivalState.festival.id == response.festivalId else { return }
        updated.festivalState.upsertPeriod(response)
        let periodIds = Set(updated.festivalState.periods.map(\.id))
        updated.districtState?.removeRoutes(outside: periodIds)
        if let routeState = updated.routeState,
           updated.period(id: routeState.route.periodId) == nil {
            updated.routeState = nil
        }
        current = updated
    }
}

func removePeriod(_ id: Period.ID, sessionId: UUID?, from appState: Shared<AppState?>) {
    appState.withLock { current in
        guard let sessionId,
              var updated = current,
              updated.sessionId == sessionId else { return }
        updated.festivalState.removePeriod(id: id)
        let periodIds = Set(updated.festivalState.periods.map(\.id))
        updated.districtState?.removeRoutes(outside: periodIds)
        if let routeState = updated.routeState,
           updated.period(id: routeState.route.periodId) == nil {
            updated.routeState = nil
        }
        current = updated
    }
}
