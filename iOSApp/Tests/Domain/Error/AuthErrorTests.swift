import Amplify
import AWSCognitoAuthPlugin
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

    @Test("SDKの設定エラーを日本語の設定エラーに変換する")
    func sdkの設定エラーを日本語の設定エラーに変換する() {
        let error = AuthError.configuration(
            "Unable to decode configuration",
            "Make sure the plugin configuration is JSONValue"
        )

        let result = AppError.parseAuth(error, operation: "signIn")

        #expect(result == .auth(.configuration("認証プラグイン設定の読み込みに失敗しました。")))
    }

    @Test("SDKの入力検証エラーを日本語の入力エラーに変換する")
    func sdkの入力検証エラーを日本語の入力エラーに変換する() {
        let error = AuthError.validation(
            "password",
            "Password is required to signIn",
            "Make sure that a valid password is passed during signIn"
        )

        let result = AppError.parseAuth(error, operation: "signIn")

        #expect(result == .auth(.badRequest("サインインに必要なパスワードが入力されていません。")))
    }

    @Test("CognitoのサービスエラーをSDKの種別に応じて日本語に変換する")
    func cognitoのサービスエラーをsdkの種別に応じて日本語に変換する() {
        let error = AuthError.service(
            "Encountered invalid password.",
            "Make sure that the password is valid",
            AWSCognitoAuthError.invalidPassword
        )

        let result = AppError.parseAuth(error, operation: "signIn")

        #expect(result == .auth(.unauthorized("パスワードが正しくありません。")))
    }

    @Test("Cognitoのネットワークエラーを日本語の通信エラーに変換する")
    func cognitoのネットワークエラーを日本語の通信エラーに変換する() {
        let error = AuthError.service(
            "Request was not completed because of a network related issue.",
            "Try again with exponential backoff",
            AWSCognitoAuthError.network
        )

        let result = AppError.parseAuth(error, operation: "getTokens")

        #expect(result == .auth(.network("通信エラーが発生しました。通信状況を確認して再試行してください。")))
    }

    @Test("SDKのセッション期限切れを日本語の認証エラーに変換する")
    func sdkのセッション期限切れを日本語の認証エラーに変換する() {
        let error = AuthError.sessionExpired(
            "Session expired could not fetch cognito tokens",
            "Invoke Auth.signIn to re-authenticate the user"
        )

        let result = AppError.parseAuth(error, operation: "getTokens")

        #expect(result == .auth(.unauthorized("セッション有効期限切れのため、認証情報を取得できませんでした。")))
    }
}
