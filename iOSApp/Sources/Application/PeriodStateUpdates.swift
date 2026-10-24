import ComposableArchitecture
import Foundation
import Shared

func applyPeriodResponse(_ response: Period, sessionId: UUID?, to appState: Shared<AppState?>) {
    appState.withLock { current in
        guard let sessionId,
              var updated = current,
              updated.sessionId == sessionId,
              updated.festivalState.festival.id == response.festivalId else { return }
        updated.festivalState.periods.removeAll { $0.id == response.id }
        if response.date.year == updated.festivalState.year {
            updated.festivalState.periods.append(response)
            updated.festivalState.periods.sort()
        }
        let periodIds = Set(updated.festivalState.periods.map(\.id))
        updated.districtState?.routes.removeAll { !periodIds.contains($0.periodId) }
        if let routeState = updated.routeState,
           !periodIds.contains(routeState.route.periodId) {
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
        updated.festivalState.periods.removeAll { $0.id == id }
        let periodIds = Set(updated.festivalState.periods.map(\.id))
        updated.districtState?.routes.removeAll { !periodIds.contains($0.periodId) }
        if let routeState = updated.routeState,
           !periodIds.contains(routeState.route.periodId) {
            updated.routeState = nil
        }
        current = updated
    }
}
