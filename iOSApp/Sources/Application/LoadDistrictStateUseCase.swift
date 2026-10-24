import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol LoadDistrictStateUseCaseProtocol: Sendable {
    func callAsFunction(
        districtId: District.ID,
        periodId: Period.ID?,
        appState: Shared<AppState?>
    ) async throws -> LaunchDistrictPack
}

extension LoadDistrictStateUseCaseProtocol {
    func callAsFunction(districtId: District.ID, appState: Shared<AppState?>) async throws -> LaunchDistrictPack {
        try await callAsFunction(districtId: districtId, periodId: nil, appState: appState)
    }
}

struct LoadDistrictStateUseCase: LoadDistrictStateUseCaseProtocol {
    @Dependency(SceneDataFetcherKey.self) private var dataFetcher

    func callAsFunction(
        districtId: District.ID,
        periodId: Period.ID? = nil,
        appState: Shared<AppState?>
    ) async throws -> LaunchDistrictPack {
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

        let response = try await dataFetcher.launchDistrict(districtId: districtId, periodId: periodId)
        appState.withLock { current in
            guard var updated = current,
                  updated.sessionId == sessionId,
                  updated.districtLoadRequestId == requestId,
                  updated.festivalState.districts.contains(where: { $0.id == districtId }) else { return }
            updated.districtState = DistrictState(
                districtId: districtId,
                requestId: requestId,
                pack: response,
                currentPeriodIds: Set(updated.festivalState.periods.map(\.id))
            )
            if let routeId = response.currentRouteId,
               let route = updated.districtState?.routes.first(where: { $0.id == routeId }) {
                updated.routeState = RouteState(route: route, points: response.points, passages: response.passages)
            }
            current = updated
        }
        return response
    }
}

enum LoadDistrictStateUseCaseKey: DependencyKey {
    static let liveValue: any LoadDistrictStateUseCaseProtocol = LoadDistrictStateUseCase()
}
