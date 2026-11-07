import ComposableArchitecture
import Dependencies

protocol SignOutUseCaseProtocol: Sendable {
    func callAsFunction(appState: Shared<AppState?>) async throws -> LaunchState
}

struct SignOutUseCase: SignOutUseCaseProtocol {
    @Dependency(\.authProvider) private var authProvider
    @Dependency(LaunchSceneUseCaseKey.self) private var launchSceneUseCase

    func callAsFunction(appState: Shared<AppState?>) async throws -> LaunchState {
        try await authProvider.signOut()
        let (launchState, _) = await launchSceneUseCase(appState: appState)
        return launchState
    }
}

enum SignOutUseCaseKey: DependencyKey {
    static let liveValue: any SignOutUseCaseProtocol = SignOutUseCase()
}
