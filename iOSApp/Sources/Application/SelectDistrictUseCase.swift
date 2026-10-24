import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol SelectDistrictUseCaseProtocol: Sendable {
    func callAsFunction(districtId: District.ID?, appState: Shared<AppState?>?) async throws -> Route.ID?
}

struct SelectDistrictUseCase: SelectDistrictUseCaseProtocol {
    @Dependency(SceneDataFetcherKey.self) private var dataFetcher
    @Dependency(UserDefaltsManagerKey.self) private var userDefaults

    func callAsFunction(districtId: District.ID?, appState: Shared<AppState?>?) async throws -> Route.ID? {
        guard let districtId else {
            userDefaults.saveDefaultDistrictId(nil)
            if let appState {
                clearDistrictState(in: appState)
            }
            return nil
        }

        let pack: LaunchDistrictPack
        if let appState {
            let context = beginDistrictStateLoad(in: appState)
            pack = try await dataFetcher.launchDistrict(districtId: districtId)
            guard applyDistrictStateResponse(pack, districtId: districtId, context: context, to: appState) else {
                return nil
            }
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
