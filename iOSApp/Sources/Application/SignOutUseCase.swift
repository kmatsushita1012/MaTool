import ComposableArchitecture
import Dependencies

protocol SignOutUseCaseProtocol: Sendable {
    func callAsFunction() async throws
}

struct SignOutUseCase: SignOutUseCaseProtocol {
    @Dependency(SceneSessionCoordinatorKey.self) private var sessionCoordinator
    @Dependency(AuthServiceKey.self) private var authService

    func callAsFunction() async throws {
        _ = try await authService.signOut()
        _ = await sessionCoordinator.beginSession()
    }
}

enum SignOutUseCaseKey: DependencyKey {
    static let liveValue: any SignOutUseCaseProtocol = SignOutUseCase()
}
