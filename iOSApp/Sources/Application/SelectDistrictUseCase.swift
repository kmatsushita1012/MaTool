import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol SelectDistrictUseCaseProtocol: Sendable {
    func callAsFunction(districtId: District.ID?, appState: Shared<AppState?>?) async throws -> Route.ID?
}

struct SelectDistrictUseCase: SelectDistrictUseCaseProtocol {
    @Dependency(SceneDataFetcherKey.self) private var dataFetcher
    @Dependency(LoadDistrictStateUseCaseKey.self) private var loadDistrictStateUseCase
    @Dependency(UserDefaltsManagerKey.self) private var userDefaults

    func callAsFunction(districtId: District.ID?, appState: Shared<AppState?>?) async throws -> Route.ID? {
        guard let districtId else {
            userDefaults.saveDefaultDistrictId(nil)
            appState?.withLock { current in
                guard var updated = current else { return }
                updated.districtLoadRequestId = UUID()
                updated.routeLoadRequestId = UUID()
                updated.districtState = nil
                updated.routeState = nil
                current = updated
            }
            return nil
        }

        let pack: LaunchDistrictPack
        if let appState {
            pack = try await loadDistrictStateUseCase(
                districtId: districtId,
                periodId: nil,
                appState: appState
            )
            guard appState.withLock({ $0?.districtState?.districtId == districtId }) else { return nil }
        } else {
            pack = try await dataFetcher.launchDistrict(districtId: districtId)
        }
        userDefaults.saveDefaultDistrictId(districtId)
        return pack.currentRouteId
    }
}

enum SelectDistrictUseCaseKey: DependencyKey {
    static let liveValue: any SelectDistrictUseCaseProtocol = SelectDistrictUseCase()
}
