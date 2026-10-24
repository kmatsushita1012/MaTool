import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol CreatePeriodUseCaseProtocol: Sendable {
    func callAsFunction(_ period: Period, appState: Shared<AppState?>) async throws -> Period
}

struct CreatePeriodUseCase: CreatePeriodUseCaseProtocol {
    @Dependency(PeriodDataFetcherKey.self) private var dataFetcher

    func callAsFunction(_ period: Period, appState: Shared<AppState?>) async throws -> Period {
        let sessionId = appState.withLock { $0?.sessionId }
        let response = try await dataFetcher.create(period)
        applyPeriodResponse(response, sessionId: sessionId, to: appState)
        return response
    }
}

enum CreatePeriodUseCaseKey: DependencyKey {
    static let liveValue: any CreatePeriodUseCaseProtocol = CreatePeriodUseCase()
}
