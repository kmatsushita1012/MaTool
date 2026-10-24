import ComposableArchitecture
import Dependencies
import Shared

protocol ReissueDistrictUseCaseProtocol: Sendable {
    func callAsFunction(
        districtId: District.ID,
        email: String,
        appState: Shared<AppState?>
    ) async throws -> DistrictPack
}

struct ReissueDistrictUseCase: ReissueDistrictUseCaseProtocol {
    @Dependency(DistrictDataFetcherKey.self) private var dataFetcher

    func callAsFunction(
        districtId: District.ID,
        email: String,
        appState: Shared<AppState?>
    ) async throws -> DistrictPack {
        let sessionId = appState.withLock { $0?.sessionId }
        let response = try await dataFetcher.reissue(districtId: districtId, email: email)
        appState.withLock { current in
            guard let sessionId,
                  var updated = current,
                  updated.sessionId == sessionId,
                  updated.festivalState.festival.id == response.district.festivalId else { return }
            replaceDistrict(response.district, in: &updated.festivalState.districts)
            current = updated
        }
        return response
    }
}

enum ReissueDistrictUseCaseKey: DependencyKey {
    static let liveValue: any ReissueDistrictUseCaseProtocol = ReissueDistrictUseCase()
}
