import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol DeletePeriodUseCaseProtocol: Sendable {
    func callAsFunction(_ period: Period, appState: Shared<AppState?>) async throws
}

struct DeletePeriodUseCase: DeletePeriodUseCaseProtocol {
    @Dependency(EditionDataFetcherKey.self) private var dataFetcher

    func callAsFunction(_ period: Period, appState: Shared<AppState?>) async throws {
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
        guard pack.periods.contains(where: { $0.id == period.id }) else {
            throw AppError.be(.notFound("対象の日程が見つかりません。"))
        }
        let savedPack = try await dataFetcher.update(EditionPack(
            edition: pack.edition,
            periods: pack.periods.filter { $0.id != period.id }
        ))
        applyEditionPack(savedPack, sessionId: context.sessionId, to: appState)
    }
}

enum DeletePeriodUseCaseKey: DependencyKey {
    static let liveValue: any DeletePeriodUseCaseProtocol = DeletePeriodUseCase()
}
