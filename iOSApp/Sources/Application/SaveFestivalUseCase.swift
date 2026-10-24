import ComposableArchitecture
import Dependencies
import Shared

protocol SaveFestivalUseCaseProtocol: Sendable {
    func callAsFunction(
        festival: Festival,
        checkpoints: [Checkpoint],
        hazardSections: [HazardSection],
        appState: Shared<AppState?>
    ) async throws -> FestivalPack
}

struct SaveFestivalUseCase: SaveFestivalUseCaseProtocol {
    @Dependency(FestivalDataFetcherKey.self) private var dataFetcher

    func callAsFunction(
        festival: Festival,
        checkpoints: [Checkpoint],
        hazardSections: [HazardSection],
        appState: Shared<AppState?>
    ) async throws -> FestivalPack {
        let sessionId = appState.withLock { $0?.sessionId }
        let response = try await dataFetcher.update(
            festival: festival,
            checkPoints: checkpoints,
            hazardSections: hazardSections
        )
        appState.withLock { current in
            guard let sessionId,
                  var updated = current,
                  updated.sessionId == sessionId,
                  updated.festivalState.festival.id == response.festival.id else { return }
            updated.festivalState.festival = response.festival
            updated.festivalState.checkpoints = response.checkpoints
            updated.festivalState.hazardSections = response.hazardSections
            current = updated
        }
        return response
    }
}

enum SaveFestivalUseCaseKey: DependencyKey {
    static let liveValue: any SaveFestivalUseCaseProtocol = SaveFestivalUseCase()
}
