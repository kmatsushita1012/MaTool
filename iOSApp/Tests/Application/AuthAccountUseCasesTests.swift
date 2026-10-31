import Dependencies
import Testing
@testable import iOSApp

struct AuthAccountUseCasesTests {
    @Test("認証アカウントUseCaseが各操作をAuthProviderへ渡す")
    func forwardsAccountOperationsToAuthProvider() async throws {
        let calls = AuthAccountCalls()
        var provider = AuthProviderSpy().client
        provider.changePassword = { current, new in
            await calls.append("change:\(current):\(new)")
        }
        provider.resetPassword = { username in
            await calls.append("reset:\(username)")
        }
        provider.confirmResetPassword = { username, password, code in
            await calls.append("confirm-reset:\(username):\(password):\(code)")
        }
        provider.updateEmail = { email in
            await calls.append("update-email:\(email)")
            return .completed
        }
        provider.confirmUpdateEmail = { code in
            await calls.append("confirm-email:\(code)")
        }

        let useCases = withDependencies {
            $0.installTestSpies()
            $0.authProvider = provider
        } operation: {
            (
                ChangePasswordUseCase(),
                ResetPasswordUseCase(),
                ConfirmResetPasswordUseCase(),
                UpdateEmailUseCase(),
                ConfirmUpdateEmailUseCase()
            )
        }

        try await useCases.0(current: "OldPass1", new: "NewPass2")
        try await useCases.1(username: "user")
        try await useCases.2(username: "user", newPassword: "NewPass2", code: "123456")
        let updateState = try await useCases.3(email: "user@example.com")
        try await useCases.4(code: "654321")

        #expect(updateState == .completed)
        #expect(await calls.values() == [
            "change:OldPass1:NewPass2",
            "reset:user",
            "confirm-reset:user:NewPass2:123456",
            "update-email:user@example.com",
            "confirm-email:654321"
        ])
    }
}

private actor AuthAccountCalls {
    private var recorded: [String] = []

    func append(_ value: String) {
        recorded.append(value)
    }

    func values() -> [String] {
        recorded
    }
}
