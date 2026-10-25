import Dependencies
import Shared

protocol ChangePasswordUseCaseProtocol: Sendable {
    func callAsFunction(current: String, new: String) async throws
}

struct ChangePasswordUseCase: ChangePasswordUseCaseProtocol {
    @Dependency(\.authProvider) private var authProvider

    func callAsFunction(current: String, new: String) async throws {
        try await authProvider.changePassword(current, new)
    }
}

enum ChangePasswordUseCaseKey: DependencyKey {
    static let liveValue: any ChangePasswordUseCaseProtocol = ChangePasswordUseCase()
}

protocol ResetPasswordUseCaseProtocol: Sendable {
    func callAsFunction(username: String) async throws
}

struct ResetPasswordUseCase: ResetPasswordUseCaseProtocol {
    @Dependency(\.authProvider) private var authProvider

    func callAsFunction(username: String) async throws {
        try await authProvider.resetPassword(username)
    }
}

enum ResetPasswordUseCaseKey: DependencyKey {
    static let liveValue: any ResetPasswordUseCaseProtocol = ResetPasswordUseCase()
}

protocol ConfirmResetPasswordUseCaseProtocol: Sendable {
    func callAsFunction(username: String, newPassword: String, code: String) async throws
}

struct ConfirmResetPasswordUseCase: ConfirmResetPasswordUseCaseProtocol {
    @Dependency(\.authProvider) private var authProvider

    func callAsFunction(username: String, newPassword: String, code: String) async throws {
        try await authProvider.confirmResetPassword(username, newPassword, code)
    }
}

enum ConfirmResetPasswordUseCaseKey: DependencyKey {
    static let liveValue: any ConfirmResetPasswordUseCaseProtocol = ConfirmResetPasswordUseCase()
}

protocol UpdateEmailUseCaseProtocol: Sendable {
    func callAsFunction(email: String) async throws -> UpdateEmailState
}

struct UpdateEmailUseCase: UpdateEmailUseCaseProtocol {
    @Dependency(\.authProvider) private var authProvider

    func callAsFunction(email: String) async throws -> UpdateEmailState {
        try await authProvider.updateEmail(email)
    }
}

enum UpdateEmailUseCaseKey: DependencyKey {
    static let liveValue: any UpdateEmailUseCaseProtocol = UpdateEmailUseCase()
}

protocol ConfirmUpdateEmailUseCaseProtocol: Sendable {
    func callAsFunction(code: String) async throws
}

struct ConfirmUpdateEmailUseCase: ConfirmUpdateEmailUseCaseProtocol {
    @Dependency(\.authProvider) private var authProvider

    func callAsFunction(code: String) async throws {
        try await authProvider.confirmUpdateEmail(code)
    }
}

enum ConfirmUpdateEmailUseCaseKey: DependencyKey {
    static let liveValue: any ConfirmUpdateEmailUseCaseProtocol = ConfirmUpdateEmailUseCase()
}
