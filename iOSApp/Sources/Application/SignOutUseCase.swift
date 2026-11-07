import ComposableArchitecture
import Dependencies

protocol SignOutUseCaseProtocol: Sendable {
    func callAsFunction(appState: Shared<AppState?>) async throws
}

struct SignOutUseCase: SignOutUseCaseProtocol {
    @Dependency(SceneSessionCoordinatorKey.self) private var sessionCoordinator
    @Dependency(\.authProvider) private var authProvider

    func callAsFunction(appState: Shared<AppState?>) async throws {
        try await authProvider.signOut()
        let sessionId = await sessionCoordinator.beginSession()
        appState.withLock { current in
            guard var festivalState = current?.festivalState else { return }
            festivalState.checkpoints = []
            festivalState.hazardSections = []
            current = AppState(festivalState: festivalState, sessionId: sessionId)
        }
    }
}

enum SignOutUseCaseKey: DependencyKey {
    static let liveValue: any SignOutUseCaseProtocol = SignOutUseCase()
}
