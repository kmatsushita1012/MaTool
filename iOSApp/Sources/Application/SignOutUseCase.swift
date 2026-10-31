import ComposableArchitecture
import Dependencies

protocol SignOutUseCaseProtocol: Sendable {
    func callAsFunction() async throws
}

struct SignOutUseCase: SignOutUseCaseProtocol {
    @Dependency(SceneSessionCoordinatorKey.self) private var sessionCoordinator
    @Dependency(\.authProvider) private var authProvider

    func callAsFunction() async throws {
        try await authProvider.signOut()
        _ = await sessionCoordinator.beginSession()
    }
}

enum SignOutUseCaseKey: DependencyKey {
    static let liveValue: any SignOutUseCaseProtocol = SignOutUseCase()
}
