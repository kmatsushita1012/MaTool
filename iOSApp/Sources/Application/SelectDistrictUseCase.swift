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

        let context = appState.map { beginDistrictStateLoad(in: $0) }
        let (festivalPack, pack) = try await fetchEditionConsistentLaunchPacks(
            districtID: districtId,
            using: dataFetcher
        )
        guard festivalPack.districts.contains(where: { $0.id == districtId }) else { return nil }
        if let appState, let context,
           !applyConsistentLaunchResponses(
            festivalPack: festivalPack,
            districtPack: pack,
            districtId: districtId,
            context: context,
            to: appState
           ) {
            return nil
        }
        userDefaults.saveDefaultDistrictId(districtId)
        return pack.currentRouteId
    }
}

enum SelectDistrictUseCaseKey: DependencyKey {
    static let liveValue: any SelectDistrictUseCaseProtocol = SelectDistrictUseCase()
}
