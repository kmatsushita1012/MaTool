import Dependencies
import Foundation
import Shared

enum AdvertiserAuthUsecaseKey: DependencyKey {
    static let liveValue: any AdvertiserAuthUsecaseProtocol = AdvertiserAuthUsecase()
}

extension DependencyValues {
    var advertiserAuthUsecase: any AdvertiserAuthUsecaseProtocol {
        get { self[AdvertiserAuthUsecaseKey.self] }
        set { self[AdvertiserAuthUsecaseKey.self] = newValue }
    }
}

protocol AdvertiserAuthUsecaseProtocol: Sendable {
    func signUp(_ request: AdvertiserSignUpRequest) async throws
    func confirmSignUp(_ request: AdvertiserConfirmSignUpRequest) async throws
}

struct AdvertiserAuthUsecase: AdvertiserAuthUsecaseProtocol {
    @Dependency(AuthManagerFactoryKey.self) var authManagerFactory

    func signUp(_ request: AdvertiserSignUpRequest) async throws {
        let email = try validatedEmail(request.email)
        guard !request.password.isEmpty else {
            throw Error.badRequest("パスワードを入力してください。")
        }

        let authManager = try await authManagerFactory()
        try await authManager.signUp(email: email, password: request.password)
    }

    func confirmSignUp(_ request: AdvertiserConfirmSignUpRequest) async throws {
        let email = try validatedEmail(request.email)
        let confirmationCode = request.confirmationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !confirmationCode.isEmpty else {
            throw Error.badRequest("確認コードを入力してください。")
        }

        let authManager = try await authManagerFactory()
        try await authManager.confirmSignUp(email: email, confirmationCode: confirmationCode)
    }

    private func validatedEmail(_ value: String) throws -> String {
        let email = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty,
              email.contains("@"),
              !email.contains(where: \.isWhitespace) else {
            throw Error.badRequest("メールアドレスが正しくありません。")
        }
        return email
    }
}
