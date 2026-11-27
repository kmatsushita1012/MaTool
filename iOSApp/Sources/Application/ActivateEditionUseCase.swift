import ComposableArchitecture
import Dependencies
import Foundation
import Shared

struct EditionActivationResult: Equatable, Sendable {
    let activeEdition: ActiveEdition
    let appStateReloadError: AppError?
}

protocol ActivateEditionUseCaseProtocol: Sendable {
    func callAsFunction(
        festivalID: Festival.ID,
        editionID: Edition.ID,
        appState: Shared<AppState?>
    ) async throws -> EditionActivationResult
}

struct ActivateEditionUseCase: ActivateEditionUseCaseProtocol {
    @Dependency(EditionDataFetcherKey.self) private var editionDataFetcher
    @Dependency(SceneDataFetcherKey.self) private var sceneDataFetcher
    @Dependency(SceneSessionCoordinatorKey.self) private var sessionCoordinator

    func callAsFunction(
        festivalID: Festival.ID,
        editionID: Edition.ID,
        appState: Shared<AppState?>
    ) async throws -> EditionActivationResult {
        let activeEdition = try await editionDataFetcher.activate(
            festivalID: festivalID,
            editionID: editionID
        )

        do {
            try await reloadCurrentSceneState(appState)
            return EditionActivationResult(activeEdition: activeEdition, appStateReloadError: nil)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return EditionActivationResult(
                activeEdition: activeEdition,
                appStateReloadError: error.asAppError
            )
        }
    }

    private func reloadCurrentSceneState(_ appState: Shared<AppState?>) async throws {
        let requestID = await sessionCoordinator.beginSession()
        let selection = appState.withLock { current -> (festivalID: Festival.ID, districtID: District.ID?, sessionID: UUID)? in
            guard let existing = current else { return nil }
            return (
                existing.festivalState.festival.id,
                existing.districtState?.districtId,
                existing.sessionId
            )
        }
        guard let selection else {
            throw AppError.system(.unexpected("アプリの起動状態を更新できませんでした。"))
        }

        if let districtID = selection.districtID {
            let (festivalPack, districtPack) = try await fetchEditionConsistentLaunchPacks(
                districtID: districtID,
                using: sceneDataFetcher
            )
            guard festivalPack.districts.contains(where: { $0.id == districtID }) else {
                throw AppError.be(.notFound("選択中の地区が祭典に見つかりません。"))
            }
            guard await sessionCoordinator.isCurrent(requestID) else { throw CancellationError() }
            let didApply = appState.withLock { current -> Bool in
                guard current?.sessionId == selection.sessionID else { return false }
                current = AppState(
                    festivalPack: festivalPack,
                    districtPack: districtPack,
                    districtId: districtID,
                    sessionId: requestID
                )
                return true
            }
            guard didApply else { throw CancellationError() }
        } else {
            let festivalPack = try await sceneDataFetcher.launchFestival(festivalId: selection.festivalID)
            guard await sessionCoordinator.isCurrent(requestID) else { throw CancellationError() }
            let didApply = appState.withLock { current -> Bool in
                guard current?.sessionId == selection.sessionID else { return false }
                current = AppState(festivalPack: festivalPack, sessionId: requestID)
                return true
            }
            guard didApply else { throw CancellationError() }
        }
    }
}

enum ActivateEditionUseCaseKey: DependencyKey {
    static let liveValue: any ActivateEditionUseCaseProtocol = ActivateEditionUseCase()
}
