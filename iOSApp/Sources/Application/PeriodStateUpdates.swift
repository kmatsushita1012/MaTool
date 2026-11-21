import ComposableArchitecture
import Foundation
import Shared

func applyEditionPack(_ pack: EditionPack, sessionId: UUID?, to appState: Shared<AppState?>) {
    appState.withLock { current in
        guard let sessionId,
              var updated = current,
              updated.sessionId == sessionId,
              updated.festivalState.festival.id == pack.edition.festivalId,
              updated.festivalState.edition?.id == pack.edition.id else { return }
        updated.festivalState.periods = pack.periods.sorted()
        let periodIds = Set(updated.festivalState.periods.map(\.id))
        updated.districtState?.removeRoutes(outside: periodIds)
        if let routeState = updated.routeState,
           updated.period(id: routeState.route.periodId) == nil {
            updated.routeState = nil
        }
        current = updated
    }
}
