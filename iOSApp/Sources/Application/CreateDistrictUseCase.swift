import ComposableArchitecture
import Dependencies
import Shared

protocol CreateDistrictUseCaseProtocol: Sendable {
    func callAsFunction(
        name: String,
        email: String,
        festivalId: Festival.ID,
        appState: Shared<AppState?>
    ) async throws -> DistrictPack
}

struct CreateDistrictUseCase: CreateDistrictUseCaseProtocol {
    @Dependency(DistrictDataFetcherKey.self) private var dataFetcher

    func callAsFunction(
        name: String,
        email: String,
        festivalId: Festival.ID,
        appState: Shared<AppState?>
    ) async throws -> DistrictPack {
        let sessionId = appState.withLock { $0?.sessionId }
        let response = try await dataFetcher.create(name: name, email: email, festivalId: festivalId)
        appState.withLock { current in
            guard let sessionId,
                  var updated = current,
                  updated.sessionId == sessionId,
                  updated.festivalState.festival.id == response.district.festivalId else { return }
            updated.festivalState.upsertDistrict(response.district)
            current = updated
        }
        return response
    }
}

enum CreateDistrictUseCaseKey: DependencyKey {
    static let liveValue: any CreateDistrictUseCaseProtocol = CreateDistrictUseCase()
}
