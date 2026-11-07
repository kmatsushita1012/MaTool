import Dependencies
import Shared

extension DependencyValues {
    var advertiserAuthUsecase: any AdvertiserAuthUsecaseProtocol {
        get { self[AdvertiserAuthUsecaseKey.self] }
        set { self[AdvertiserAuthUsecaseKey.self] = newValue }
    }
}

enum AdvertiserSignUpResult: Equatable, Sendable {
    case confirmationRequired
    case signedIn(UserRole)
}

protocol AdvertiserAuthUsecaseProtocol: Sendable {
    func signUp(email: String, password: String) async throws -> AdvertiserSignUpResult
    func confirmSignUp(email: String, password: String, code: String) async throws -> UserRole
    func signIn(email: String, password: String) async throws -> UserRole
}

struct AdvertiserAuthUsecase: AdvertiserAuthUsecaseProtocol {
    @Dependency(\.authProvider) private var authProvider

    func signUp(email: String, password: String) async throws -> AdvertiserSignUpResult {
        let requiresConfirmation = try await authProvider.signUp(email, password)
        if requiresConfirmation {
            return .confirmationRequired
        }
        return .signedIn(try await signIn(email: email, password: password))
    }

    func confirmSignUp(email: String, password: String, code: String) async throws -> UserRole {
        guard try await authProvider.confirmSignUp(email, code) else {
            throw AppError.auth(.badRequest("確認コードを完了できませんでした。"))
        }
        return try await signIn(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws -> UserRole {
        switch try await authProvider.signIn(email, password) {
        case .newPasswordRequired:
            throw AppError.auth(.unauthorized("広告主アカウントでログインしてください。"))
        case .success:
            let role: UserRole
            do {
                role = try await authProvider.getUserRole()
            } catch {
                try? await authProvider.signOut()
                throw error
            }
            guard case .advertiser = role else {
                try? await authProvider.signOut()
                throw AppError.auth(.forbidden("広告主アカウントでログインしてください。"))
            }
            return role
        }
    }
}

enum AdvertiserAuthUsecaseKey: DependencyKey {
    static let liveValue: any AdvertiserAuthUsecaseProtocol = AdvertiserAuthUsecase()
}
