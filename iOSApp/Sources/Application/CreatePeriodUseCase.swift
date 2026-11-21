import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol CreatePeriodUseCaseProtocol: Sendable {
    func callAsFunction(_ period: Period, appState: Shared<AppState?>) async throws -> Period
}

struct CreatePeriodUseCase: CreatePeriodUseCaseProtocol {
    @Dependency(EditionDataFetcherKey.self) private var dataFetcher

    func callAsFunction(_ period: Period, appState: Shared<AppState?>) async throws -> Period {
        let context = appState.withLock { current -> (sessionId: UUID, festivalID: Festival.ID)? in
            guard let current else { return nil }
            return (current.sessionId, current.festivalState.festival.id)
        }
        guard let context, let editionID = period.editionId else {
            throw AppError.validation(.badRequest("有効な年度を選択してください。"))
        }
        let pack = try await fetchEditionPack(
            festivalID: context.festivalID,
            editionID: editionID,
            using: dataFetcher
        )
        var periods = pack.periods
        periods.removeAll { $0.id == period.id }
        periods.append(period)
        let savedPack = try await dataFetcher.update(EditionPack(edition: pack.edition, periods: periods.sorted()))
        applyEditionPack(savedPack, sessionId: context.sessionId, to: appState)
        return savedPack.periods.first(where: { $0.id == period.id }) ?? period
    }
}

enum CreatePeriodUseCaseKey: DependencyKey {
    static let liveValue: any CreatePeriodUseCaseProtocol = CreatePeriodUseCase()
}
