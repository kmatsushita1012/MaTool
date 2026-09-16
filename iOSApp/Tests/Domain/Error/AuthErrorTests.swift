import Amplify
import Testing
@testable import iOSApp

struct AuthErrorTests {
    @Test("Amplifyのサインイン失敗を日本語に変換する")
    func amplifyのサインイン失敗を日本語に変換する() {
        let error = AuthError.notAuthorized(
            "Incorrect username or password.",
            "Check whether the given values are correct."
        )

        let result = AppError.parseAuth(error, operation: "signIn")

        #expect(result == .auth(.unauthorized("ユーザー名またはパスワードが正しくありません。")))
    }

    @Test("SDKメッセージ末尾の句点に依存しない")
    func sdkメッセージ末尾の句点に依存しない() {
        let error = AuthError.service(
            "Incorrect username or password.",
            "Check whether the given values are correct."
        )

        let result = AppError.parseAuth(error, operation: "signIn")

        #expect(result == .auth(.unauthorized("ユーザー名またはパスワードが正しくありません。")))
    }

    @Test("未知のAmplifyエラーを英語のまま表示しない")
    func 未知のamplifyエラーを英語のまま表示しない() {
        let error = AuthError.service(
            "An unexpected service error.",
            "Retry the operation."
        )

        let result = AppError.parseAuth(error, operation: "signIn")

        #expect(result == .auth(.unknown("認証処理でエラーが発生しました。")))
    }
}
