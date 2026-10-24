import ComposableArchitecture
import Dependencies
import Shared

protocol SaveDistrictPackUseCaseProtocol: Sendable {
    func callAsFunction(
        district: District,
        performances: [Performance],
        appState: Shared<AppState?>
    ) async throws -> DistrictPack
}

struct SaveDistrictPackUseCase: SaveDistrictPackUseCaseProtocol {
    @Dependency(DistrictDataFetcherKey.self) private var dataFetcher

    func callAsFunction(
        district: District,
        performances: [Performance],
        appState: Shared<AppState?>
    ) async throws -> DistrictPack {
        let sessionId = appState.withLock { $0?.sessionId }
        let response = try await dataFetcher.update(district: district, performances: performances)
        appState.withLock { current in
            guard let sessionId,
                  var updated = current,
                  updated.sessionId == sessionId,
                  updated.festivalState.festival.id == response.district.festivalId else { return }
            replaceDistrict(response.district, in: &updated.festivalState.districts)
            if updated.districtState?.districtId == response.district.id {
                updated.districtState?.performances = response.performances
            }
            current = updated
        }
        return response
    }
}

enum SaveDistrictPackUseCaseKey: DependencyKey {
    static let liveValue: any SaveDistrictPackUseCaseProtocol = SaveDistrictPackUseCase()
}
