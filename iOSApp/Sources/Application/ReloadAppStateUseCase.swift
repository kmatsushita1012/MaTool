import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol ReloadAppStateUseCaseProtocol: Sendable {
    func callAsFunction(appState: Shared<AppState?>) async throws
}

struct ReloadAppStateUseCase: ReloadAppStateUseCaseProtocol {
    @Dependency(SceneDataFetcherKey.self) private var dataFetcher
    @Dependency(SceneSessionCoordinatorKey.self) private var sessionCoordinator

    func callAsFunction(appState: Shared<AppState?>) async throws {
        let requestId = await sessionCoordinator.beginSession()
        let selection = appState.withLock { current -> (festivalId: Festival.ID, districtId: District.ID?)? in
            guard let existing = current else { return nil }
            current = AppState(
                festivalState: existing.festivalState,
                districtState: existing.districtState,
                routeState: existing.routeState,
                sessionId: requestId
            )
            return (existing.festivalState.festival.id, existing.districtState?.districtId)
        }
        guard let selection else {
            throw AppError.system(.unexpected("アプリの起動状態を更新できませんでした。"))
        }

        if let districtId = selection.districtId {
            let (festivalPack, districtPack) = try await fetchEditionConsistentLaunchPacks(
                districtID: districtId,
                using: dataFetcher
            )
            guard festivalPack.districts.contains(where: { $0.id == districtId }) else {
                throw AppError.be(.notFound("選択中の地区が祭典に見つかりません。"))
            }
            guard await sessionCoordinator.isCurrent(requestId) else { throw CancellationError() }
            appState.withLock { current in
                guard current?.sessionId == requestId else { return }
                current = AppState(
                    festivalPack: festivalPack,
                    districtPack: districtPack,
                    districtId: districtId,
                    sessionId: requestId
                )
            }
        } else {
            let festivalPack = try await dataFetcher.launchFestival(festivalId: selection.festivalId)
            guard await sessionCoordinator.isCurrent(requestId) else { throw CancellationError() }
            appState.withLock { current in
                guard current?.sessionId == requestId else { return }
                current = AppState(festivalPack: festivalPack, sessionId: requestId)
            }
        }
    }
}

enum ReloadAppStateUseCaseKey: DependencyKey {
    static let liveValue: any ReloadAppStateUseCaseProtocol = ReloadAppStateUseCase()
}
