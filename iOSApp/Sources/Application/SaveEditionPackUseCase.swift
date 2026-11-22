import ComposableArchitecture
import Dependencies
import Shared

protocol SaveEditionPackUseCaseProtocol: Sendable {
    func callAsFunction(_ pack: EditionPack, appState: Shared<AppState?>) async throws -> EditionPack
}

struct SaveEditionPackUseCase: SaveEditionPackUseCaseProtocol {
    @Dependency(EditionDataFetcherKey.self) private var dataFetcher

    func callAsFunction(_ pack: EditionPack, appState: Shared<AppState?>) async throws -> EditionPack {
        let sessionId = appState.withLock { $0?.sessionId }
        let response = try await dataFetcher.update(pack)
        applyEditionPack(response, sessionId: sessionId, to: appState)
        return response
    }
}

enum SaveEditionPackUseCaseKey: DependencyKey {
    static let liveValue: any SaveEditionPackUseCaseProtocol = SaveEditionPackUseCase()
}
