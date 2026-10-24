import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol SelectFestivalUseCaseProtocol: Sendable {
    func callAsFunction(festivalId: Festival.ID, appState: Shared<AppState?>?) async throws -> FestivalSelectionResult
}

struct SelectFestivalUseCase: SelectFestivalUseCaseProtocol {
    @Dependency(SceneDataFetcherKey.self) private var dataFetcher
    @Dependency(SceneSessionCoordinatorKey.self) private var sessionCoordinator
    @Dependency(AuthServiceKey.self) private var authService
    @Dependency(UserDefaltsManagerKey.self) private var userDefaults

    func callAsFunction(festivalId: Festival.ID, appState: Shared<AppState?>?) async throws -> FestivalSelectionResult {
        guard userDefaults.defaultFestivalId != festivalId else { return .unchanged }
        let requestId = await sessionCoordinator.beginSession()
        appState?.withLock { $0 = nil }
        _ = try await authService.signOut()
        let response = try await dataFetcher.launchFestival(festivalId: festivalId)
        guard await sessionCoordinator.isCurrent(requestId) else { throw CancellationError() }
        if let appState {
            appState.withLock {
                $0 = AppState(
                    festivalPack: response,
                    year: Calendar.current.component(.year, from: .now),
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
