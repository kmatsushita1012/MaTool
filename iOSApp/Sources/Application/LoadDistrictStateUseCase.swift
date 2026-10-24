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
        let context = beginDistrictStateLoad(in: appState)

        let response = try await dataFetcher.launchDistrict(districtId: districtId, periodId: periodId)
        applyDistrictStateResponse(response, districtId: districtId, context: context, to: appState)
        return response
    }
}

enum LoadDistrictStateUseCaseKey: DependencyKey {
    static let liveValue: any LoadDistrictStateUseCaseProtocol = LoadDistrictStateUseCase()
}
