import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol LoadAppStateUseCaseProtocol: Sendable {
    func callAsFunction(
        _ festivalPack: LaunchFestivalPack,
        districtPack: LaunchDistrictPack?,
        districtId: District.ID?,
        year: Int,
        sessionId: UUID,
        appState: Shared<AppState?>
    ) -> Route.ID?
}

struct LoadAppStateUseCase: LoadAppStateUseCaseProtocol {
    func callAsFunction(
        _ festivalPack: LaunchFestivalPack,
        districtPack: LaunchDistrictPack? = nil,
        districtId: District.ID? = nil,
        year: Int = Calendar.current.component(.year, from: .now),
        sessionId: UUID = UUID(),
        appState: Shared<AppState?>
    ) -> Route.ID? {
        let festivalState = FestivalState(festivalPack, year: year)
        let districtState: DistrictState? = districtPack.flatMap { pack in
            guard let districtId else { return nil }
            return DistrictState(
                districtId: districtId,
                pack: pack,
                currentPeriodIds: Set(festivalState.periods.map(\.id))
            )
        }
        let routeState: RouteState? = districtPack.flatMap { pack in
            guard let routeId = pack.currentRouteId,
                  let route = districtState?.routes.first(where: { $0.id == routeId }) else { return nil }
            return RouteState(route: route, points: pack.points, passages: pack.passages)
        }
        appState.withLock {
            $0 = AppState(
                festivalState: festivalState,
                districtState: districtState,
                routeState: routeState,
                sessionId: sessionId
            )
        }
        return districtPack?.currentRouteId
    }
}

enum LoadAppStateUseCaseKey: DependencyKey {
    static let liveValue: any LoadAppStateUseCaseProtocol = LoadAppStateUseCase()
}
