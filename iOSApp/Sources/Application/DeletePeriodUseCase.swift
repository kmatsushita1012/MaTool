import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol DeletePeriodUseCaseProtocol: Sendable {
    func callAsFunction(id: Period.ID, appState: Shared<AppState?>) async throws
}

struct DeletePeriodUseCase: DeletePeriodUseCaseProtocol {
    @Dependency(PeriodDataFetcherKey.self) private var dataFetcher

    func callAsFunction(id: Period.ID, appState: Shared<AppState?>) async throws {
        let sessionId = appState.withLock { $0?.sessionId }
        try await dataFetcher.delete(id)
        removePeriod(id, sessionId: sessionId, from: appState)
    }
}

enum DeletePeriodUseCaseKey: DependencyKey {
    static let liveValue: any DeletePeriodUseCaseProtocol = DeletePeriodUseCase()
}
