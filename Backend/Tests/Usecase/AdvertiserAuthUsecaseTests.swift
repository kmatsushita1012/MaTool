import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct AdvertiserAuthUsecaseTests {
    @Test("新規広告主登録では前後空白を除いたメールアドレスとパスワードを認証依存へ渡す")
    func signUpTrimsEmailAndForwardsCredentials() async throws {
        let auth = AdvertiserAuthManagerSpy()
        try await withDependencies {
            $0[AuthManagerFactoryKey.self] = { auth }
        } operation: {
            try await AdvertiserAuthUsecase().signUp(.init(
                email: "  owner@example.com \n",
                password: "StrongPass123"
            ))
        }

        let requests = await auth.signUpRequests
        #expect(requests.count == 1)
        #expect(requests.first?.email == "owner@example.com")
        #expect(requests.first?.password == "StrongPass123")
    }

    @Test("登録のメールアドレス不正または空パスワードは認証依存の起動前に拒否する")
    func signUpRejectsInvalidInputs() async {
        let cases: [(email: String, password: String, reason: String)] = [
            ("", "StrongPass123", "メールアドレスが正しくありません。"),
            ("owner.example.com", "StrongPass123", "メールアドレスが正しくありません。"),
            ("bad email@example.com", "StrongPass123", "メールアドレスが正しくありません。"),
            ("owner@example.com", "", "パスワードを入力してください。")
        ]
        for candidate in cases {
            do {
                try await withDependencies {
                    $0[AuthManagerFactoryKey.self] = { throw TestError.unimplemented }
                } operation: {
                    try await AdvertiserAuthUsecase().signUp(.init(
                        email: candidate.email, password: candidate.password
                    ))
                }
                Issue.record("不正な入力 \(candidate.email) の登録が成功してしまった")
            } catch {
                #expect((error as? Application.Error)?.localizedDescription == candidate.reason)
            }
        }
    }

    @Test("確認コードでは前後空白を取り除き、正しいメールとともに認証依存へ渡す")
    func confirmSignUpTrimsEmailAndCode() async throws {
        let auth = AdvertiserAuthManagerSpy()
        try await withDependencies {
            $0[AuthManagerFactoryKey.self] = { auth }
        } operation: {
            try await AdvertiserAuthUsecase().confirmSignUp(.init(
                email: " owner@example.com ",
                confirmationCode: " 123456 \n"
            ))
        }

        let requests = await auth.confirmRequests
        #expect(requests.count == 1)
        #expect(requests.first?.email == "owner@example.com")
        #expect(requests.first?.code == "123456")
    }

    @Test("確認コードが空白だけなら認証依存へ接続せず拒否する")
    func confirmSignUpRejectsEmptyCode() async {
        do {
            try await withDependencies {
                $0[AuthManagerFactoryKey.self] = { throw TestError.unimplemented }
            } operation: {
                try await AdvertiserAuthUsecase().confirmSignUp(.init(
                    email: "owner@example.com", confirmationCode: " \n  "
                ))
            }
            Issue.record("空の確認コードが受け入れられてしまった")
        } catch {
            #expect((error as? Application.Error)?.localizedDescription == "確認コードを入力してください。")
        }
    }
}

private actor AdvertiserAuthManagerSpy: AuthManager {
    struct SignUpRequest: Sendable {
        let email: String
        let password: String
    }
    struct ConfirmRequest: Sendable {
        let email: String
        let code: String
    }

    private(set) var signUpRequests: [SignUpRequest] = []
    private(set) var confirmRequests: [ConfirmRequest] = []

    func signUp(email: String, password: String) async throws {
        signUpRequests.append(.init(email: email, password: password))
    }

    func confirmSignUp(email: String, confirmationCode: String) async throws {
        confirmRequests.append(.init(email: email, code: confirmationCode))
    }

    func create(username: String, email: String) async throws -> UserRole {
        throw TestError.unimplemented
    }
    func delete(username: String) async throws {
        throw TestError.unimplemented
    }
    func get(accessToken: String) async throws -> UserRole {
        throw TestError.unimplemented
    }
    func get(username: String) async throws -> UserRole {
        throw TestError.unimplemented
    }
}
