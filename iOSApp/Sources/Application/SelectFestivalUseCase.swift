import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol SelectFestivalUseCaseProtocol: Sendable {
    func callAsFunction(
        festivalId: Festival.ID,
        appState: Shared<AppState?>?,
        signOutCurrentUser: Bool
    ) async throws -> FestivalSelectionResult
}

extension SelectFestivalUseCaseProtocol {
    func callAsFunction(
        festivalId: Festival.ID,
        appState: Shared<AppState?>?
    ) async throws -> FestivalSelectionResult {
        try await callAsFunction(
            festivalId: festivalId,
            appState: appState,
            signOutCurrentUser: true
        )
    }
}

struct SelectFestivalUseCase: SelectFestivalUseCaseProtocol {
    @Dependency(SceneDataFetcherKey.self) private var dataFetcher
    @Dependency(SceneSessionCoordinatorKey.self) private var sessionCoordinator
    @Dependency(\.authProvider) private var authProvider
    @Dependency(UserDefaltsManagerKey.self) private var userDefaults

    func callAsFunction(
        festivalId: Festival.ID,
        appState: Shared<AppState?>?,
        signOutCurrentUser: Bool
    ) async throws -> FestivalSelectionResult {
        guard userDefaults.defaultFestivalId != festivalId else { return .unchanged }
        let previousSessionId = appState?.wrappedValue?.sessionId
        let requestId = await sessionCoordinator.beginSession()
        let response = try await dataFetcher.launchFestival(festivalId: festivalId)
        guard await sessionCoordinator.isCurrent(requestId) else { throw CancellationError() }
        // Keep the current session and its selected festival intact until the
        // replacement pack is ready. In particular, do not sign an administrator
        // out while their old privileged AppState is still the active scene state.
        if signOutCurrentUser {
            try await authProvider.signOut()
        }
        guard await sessionCoordinator.isCurrent(requestId) else {
            // If authentication was already cleared by this request, do not leave
            // that same administrator session's cached data visible in the scene.
            appState?.withLock {
                if $0?.sessionId == previousSessionId {
                    $0 = nil
                }
            }
            throw CancellationError()
        }
        if let appState {
            appState.withLock {
                $0 = AppState(
                    festivalPack: response,
                    sessionId: requestId
                )
            }
        }
        userDefaults.saveDefaultFestivalId(festivalId)
        userDefaults.saveDefaultDistrictId(nil)
        return .changed(.guest)
    }
}

enum SelectFestivalUseCaseKey: DependencyKey {
    static let liveValue: any SelectFestivalUseCaseProtocol = SelectFestivalUseCase()
}
