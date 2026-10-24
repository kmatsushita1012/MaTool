import ComposableArchitecture
import Dependencies
import Shared

protocol SaveLocationUseCaseProtocol: Sendable {
    func callAsFunction(_ location: FloatLocation, appState: Shared<AppState?>) async throws -> FloatLocation
}

struct SaveLocationUseCase: SaveLocationUseCaseProtocol {
    @Dependency(LocationDataFetcherKey.self) private var dataFetcher

    func callAsFunction(_ location: FloatLocation, appState: Shared<AppState?>) async throws -> FloatLocation {
        let sessionId = appState.withLock { $0?.sessionId }
        let response = try await dataFetcher.update(location)
        appState.withLock { current in
            guard let sessionId,
                  var updated = current,
                  updated.sessionId == sessionId,
                  updated.festivalState.containsDistrict(id: response.districtId) else { return }
            updated.festivalState.upsertFloatLocation(response)
            current = updated
        }
        return response
    }
}

enum SaveLocationUseCaseKey: DependencyKey {
    static let liveValue: any SaveLocationUseCaseProtocol = SaveLocationUseCase()
}
