import ComposableArchitecture
import Dependencies
import Shared

protocol SaveDistrictUseCaseProtocol: Sendable {
    func callAsFunction(district: District, appState: Shared<AppState?>) async throws -> District
}

struct SaveDistrictUseCase: SaveDistrictUseCaseProtocol {
    @Dependency(DistrictDataFetcherKey.self) private var dataFetcher

    func callAsFunction(district: District, appState: Shared<AppState?>) async throws -> District {
        let sessionId = appState.withLock { $0?.sessionId }
        let response = try await dataFetcher.update(district: district)
        appState.withLock { current in
            guard let sessionId,
                  var updated = current,
                  updated.sessionId == sessionId,
                  updated.festivalState.festival.id == response.festivalId else { return }
            updated.festivalState.replaceDistrict(response)
            current = updated
        }
        return response
    }
}

enum SaveDistrictUseCaseKey: DependencyKey {
    static let liveValue: any SaveDistrictUseCaseProtocol = SaveDistrictUseCase()
}
