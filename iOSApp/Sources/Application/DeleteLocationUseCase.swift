import ComposableArchitecture
import Dependencies
import Shared

protocol DeleteLocationUseCaseProtocol: Sendable {
    func callAsFunction(districtId: District.ID, appState: Shared<AppState?>) async throws
}

struct DeleteLocationUseCase: DeleteLocationUseCaseProtocol {
    @Dependency(LocationDataFetcherKey.self) private var dataFetcher

    func callAsFunction(districtId: District.ID, appState: Shared<AppState?>) async throws {
        let sessionId = appState.withLock { $0?.sessionId }
        try await dataFetcher.delete(districtId: districtId)
        appState.withLock { current in
            guard let sessionId,
                  var updated = current,
                  updated.sessionId == sessionId else { return }
            updated.festivalState.removeFloatLocation(for: districtId)
            current = updated
        }
    }
}

enum DeleteLocationUseCaseKey: DependencyKey {
    static let liveValue: any DeleteLocationUseCaseProtocol = DeleteLocationUseCase()
}
