//
//  AuthError.swift
//  MaTool
//
//  Created by 松下和也 on 2025/06/19.
//

import Foundation
import Amplify

enum AuthError: LocalizedError, Equatable {
    case network(String)
    case encoding(String)
    case decoding(String)
    case unknown(String)
    case auth(String)
    case timeout(String)
    
    var errorDescription: String? {
        switch self {
        case .network(let message):
            return "\(message)"
        case .encoding(let message):
            return "\(message)"
        case .decoding(let message):
            return "\(message)"
        case .unknown(let message):
            return "\(message)"
        case .auth(let message):
            return "\(message)"
        case .timeout(let message):
            return "タイムアウト \(message) このエラーが繰り返し発生する場合は、設定画面からログアウトし、再度サインインしてください。"
        }
    }
}

extension AuthError {
    static func parse(_ error: Error, operation: String) -> AuthError? {
        // FIXME: エラー網羅後に削除
        print(error)
        if let authError = error as? AuthError {
            return authError
        }

        if let amplifyError = error as? any AmplifyError {
            let description = amplifyError.errorDescription
            let recovery = amplifyError.recoverySuggestion
            let message = localizedAmplifyMessage(
                description: description,
                recovery: recovery
            )

            if isAuthRelated(description: description) {
                return .auth(message)
            }
            if isNetworkRelated(description: description) {
                return .network(message)
            }
            return .unknown(message)
        }

        if error is CancellationError {
            return .timeout(operation)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .timeout(operation)
            case NSURLErrorNotConnectedToInternet,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorDNSLookupFailed:
                return .network(composeMessage(
                    main: "通信環境が不安定なため処理に失敗しました。",
                    recovery: "通信状況をご確認のうえ、時間をおいて再試行してください。"
                ))
            default:
                break
            }
        }

        return nil
    }

    private static func localizedAmplifyMessage(description: String, recovery: String) -> String {
        composeMessage(
            main: localizedAmplifyDescription(description),
            recovery: localizedAmplifyRecovery(recovery)
        )
    }

    private static func composeMessage(main: String, recovery: String) -> String {
        main
    }

    private static func localizedAmplifyDescription(_ description: String) -> String {
        switch normalize(description) {
        // MARK: - 出現を確認済
        case "Incorrect username or password":
            return "ユーザー名またはパスワードが正しくありません。"
        case "Username is required to signIn":
            return "サインインに必要なユーザー名が入力されていません。"
        case "Password is required to signIn":
            return "サインインに必要なパスワードが入力されていません。"
        case "Invalid email address format":
            return "有効なメールアドレスを入力してください。"
        case "Invalid verification code provided, please try again":
            return "認証コードが正しくありません。もう一度お試しください。"
        case "Attempt limit exceeded, please try after some time":
            return "試行回数が限界に達しています。しばらくしてから再度お試しください。"
        // MARK: - 未確認
        case "Username is required to signUp":
            return "サインアップに必要なユーザー名が入力されていません。"
        case "Password is required to signUp":
            return "サインアップに必要なパスワードが入力されていません。"
        case "Username is required to confirmSignUp":
            return "サインアップ確認に必要なユーザー名が入力されていません。"
        case "code is required to confirmSignUp":
            return "サインアップ確認に必要な確認コードが入力されていません。"
        case "challengeResponse is required to confirmSignIn":
            return "サインイン確認に必要な応答値が不足しています。"
        case "challengeResponse for MFA selection can only have SMS_MFA or SOFTWARE_TOKEN_MFA":
            return "MFA選択の応答値が不正です。SMS_MFA または SOFTWARE_TOKEN_MFA を指定してください。"
        case "challengeResponse for factor selection can only be one of the `AuthFactorType` values":
            return "認証要素選択の応答値が不正です。AuthFactorType のいずれかを指定してください。"
        case "username is required to confirmResetPassword":
            return "パスワード再設定確認に必要なユーザー名が入力されていません。"
        case "newPassword is required to confirmResetPassword":
            return "パスワード再設定確認に必要な新しいパスワードが入力されていません。"
        case "confirmationCode is required to confirmResetPassword":
            return "パスワード再設定確認に必要な確認コードが入力されていません。"
        case "username is required to resetPassword":
            return "パスワードリセットに必要なユーザー名が入力されていません。"
        case "Unable to decode configuration":
            return "認証プラグイン設定の読み込みに失敗しました。"
        case "Configuration was not a dictionary literal":
            return "認証プラグイン設定の形式が不正です。"
        case "Found invalid parameter while parsing the webUI redirect URL":
            return "サインイン後のリダイレクトURLが不正です。"
        case "User cancelled the signIn flow and could not be completed":
            return "サインイン操作がキャンセルされました。"
        case "User cancelled the signOut flow and could not be completed":
            return "サインアウト操作がキャンセルされました。"
        case "Presentation context provided is invalid or not present":
            return "認証画面の表示コンテキストが不正です。"
        case "Unable to start a ASWebAuthenticationSession":
            return "認証セッションを開始できませんでした。"
        case "SignIn URI could not be created":
            return "サインイン用URLの生成に失敗しました。"
        case "Token URI could not be created":
            return "トークン取得用URLの生成に失敗しました。"
        case "SignOut URI could not be created":
            return "サインアウト用URLの生成に失敗しました。"
        case "Callback URL could not be retrieved":
            return "コールバックURLの取得に失敗しました。"
        case "Proof calculation failed":
            return "認証検証情報の生成に失敗しました。"
        case "Token returned by service could not be parsed":
            return "サーバーから返却されたトークンの解析に失敗しました。"
        case "Could not validate the user":
            return "ユーザーの認証状態を確認できませんでした。"
        case "There is no user signed in to retreive identity id",
            "There is no user signed in to retrieve identity id":
            return "サインイン中のユーザーがいないため、Identity IDを取得できませんでした。"
        case "There is no user signed in to retreive AWS credentials",
            "There is no user signed in to retrieve AWS credentials":
            return "サインイン中のユーザーがいないため、AWS認証情報を取得できませんでした。"
        case "There is no user signed in to retreive cognito tokens",
            "There is no user signed in to retrieve cognito tokens":
            return "サインイン中のユーザーがいないため、トークンを取得できませんでした。"
        case "There is no user signed in to retreive user sub",
            "There is no user signed in to retrieve user sub":
            return "サインイン中のユーザーがいないため、ユーザーIDを取得できませんでした。"
        case "Could not fetch attributes, there is no user signed in to the Auth category":
            return "サインイン中のユーザーがいないため、ユーザー属性を取得できませんでした。"
        case "Could not update attributes, there is no user signed in to the Auth category":
            return "サインイン中のユーザーがいないため、ユーザー属性を更新できませんでした。"
        case "Could not resend attribute confirmation code, there is no user signed in to the Auth category":
            return "サインイン中のユーザーがいないため、確認コードを再送できませんでした。"
        case "Could not confirm attribute, there is no user signed in to the Auth category":
            return "サインイン中のユーザーがいないため、属性確認を完了できませんでした。"
        case "Could not change password, there is no user signed in to the Auth category":
            return "サインイン中のユーザーがいないため、パスワードを変更できませんでした。"
        case "Could not change password, the user session is expired":
            return "セッション有効期限切れのため、パスワードを変更できませんでした。"
        case "A service error occured while trying to fetch identity id",
            "A service error occured while trying to fetch AWS credentials",
            "A service error occurred while trying to fetch identity id",
            "A service error occurred while trying to fetch AWS credentials":
            return "認証サービス側エラーのため、認証情報を取得できませんでした。"
        case "Session expired could not fetch identity id",
            "Session expired could not fetch AWS Credentials",
            "Session expired could not fetch user sub",
            "Session expired could not fetch cognito tokens":
            return "セッション有効期限切れのため、認証情報を取得できませんでした。"
        case "User is not signed in through Cognito User pool":
            return "Cognito User Poolでのサインイン状態ではないため、要求された情報を取得できませんでした。"
        case "Could not fetch identity Id, AWS Cognito Identity Pool is not configured":
            return "AWS Cognito Identity Poolが未設定のため、Identity IDを取得できませんでした。"
        case "Could not fetch AWS Credentials, AWS Cognito Identity Pool is not configured":
            return "AWS Cognito Identity Poolが未設定のため、AWS認証情報を取得できませんでした。"
        case "User cancelled the creation of a new WebAuthn credential":
            return "WebAuthn資格情報の作成がキャンセルされました。"
        case "The user already has associated a WebAuthn credential with this device":
            return "この端末には既にWebAuthn資格情報が登録されています。"
        case "Unable to complete the association of the given WebAuthn credential":
            return "WebAuthn資格情報の関連付けに失敗しました。"
        case "Unable to complete assertion of the given WebAuthn credential":
            return "WebAuthn認証の検証に失敗しました。"
        case "A network error occured while trying to fetch identity id",
            "A network error occured while trying to fetch AWS credentials",
            "A network error occured while trying to fetch user sub",
            "A network error occured while trying to fetch AWS Cognito Tokens",
            "A network error occurred while trying to fetch identity id",
            "A network error occurred while trying to fetch AWS credentials",
            "A network error occurred while trying to fetch user sub",
            "A network error occurred while trying to fetch AWS Cognito Tokens":
            return "通信エラーのため、認証情報を取得できませんでした。"
        case "There is no user signed in to the Auth category":
            return "サインイン中のユーザーがいないため、認証操作を実行できませんでした。"
        default:
            return "認証処理でエラーが発生しました。"
        }
    }

    private static func localizedAmplifyRecovery(_ recovery: String) -> String {
        switch normalize(recovery) {
        // MARK: - 確認
        case "Check whether the given values are correct and the user is authorized to perform the operation":
            return "入力値（ユーザー名・パスワード）と、操作権限が正しいか確認してください。"
        case "Make sure that a valid username is passed during signIn":
            return "サインイン時に有効なユーザー名を入力してください。"
        case "Make sure that a valid password is passed during signIn":
            return "サインイン時に有効なパスワードを入力してください。"
        case "Retry with a valid code":
            return "有効な確認コードを入力し、もう一度試してみてください。"
        // MARK: - 未確認
        case "Make sure that a valid username is passed for signUp":
            return "サインアップ時に有効なユーザー名を入力してください。"
        case "Make sure that a valid password is passed for signUp":
            return "サインアップ時に有効なパスワードを入力してください。"
        case "Make sure that a valid username is passed for confirmSignUp":
            return "サインアップ確認時に有効なユーザー名を入力してください。"
        case "Make sure that a valid code is passed for confirmSignUp":
            return "サインアップ確認時に有効な確認コードを入力してください。"
        case "Make sure that a valid challenge response is passed for confirmSignIn":
            return "サインイン確認時に有効な応答値を指定してください。"
        case "Make sure that a valid username is passed for confirmResetPassword":
            return "パスワード再設定確認時に有効なユーザー名を入力してください。"
        case "Make sure that a valid newPassword is passed for confirmResetPassword":
            return "パスワード再設定確認時に有効な新しいパスワードを入力してください。"
        case "Make sure that a valid confirmationCode is passed for confirmResetPassword":
            return "パスワード再設定確認時に有効な確認コードを入力してください。"
        case "Make sure that a valid username is passed for resetPassword":
            return "パスワードリセット時に有効なユーザー名を入力してください。"
        case "Make sure the plugin configuration is JSONValue":
            return "認証プラグイン設定をJSON形式で正しく設定してください。"
        case "Make sure the value for the plugin is a dictionary literal":
            return "認証プラグイン設定を辞書形式で正しく設定してください。"
        case "Make sure that the signIn URL has not been modified during the signIn flow":
            return "サインイン中にURLが書き換わっていないか確認し、再試行してください。"
        case "Present the signIn UI again for the user to sign in":
            return "サインイン画面を再表示し、再度サインインしてください。"
        case "Present the signOut UI again for the user to sign out":
            return "サインアウト操作を再実行してください。"
        case "Retry by providing a presentation context to present the webUI":
            return "表示コンテキストを正しく指定して再試行してください。"
        case "Make sure that the app can present an ASWebAuthenticationSession":
            return "アプリがASWebAuthenticationSessionを表示できる状態か確認してください。"
        case "Check the configuration to make sure that HostedUI related information are present":
            return "Hosted UIの設定値（URL等）が正しいか確認してください。"
        case "Reach out with amplify team via github to raise an issue":
            return "同じ事象が続く場合は実装設定を見直し、必要ならAmplifyのIssue情報を確認してください。"
        case "Check if the the configuration provided are correct":
            return "認証設定値が正しいか確認してください。"
        case "SignIn to Auth category by using one of the sign in methods and then call user attributes apis":
            return "サインイン後に、再度同じ操作を行ってください。"
        case "Get the current user Auth.getCurrentUser() and make the request":
            return "サインイン状態を確認し、必要に応じて再ログインしてから再試行してください。"
        case "Call Auth.signIn to sign in a user or enable unauthenticated access in AWS Cognito Identity Pool":
            return "サインインするか、必要に応じてIdentity Poolの未認証アクセス設定を確認してください。"
        case "Call Auth.signIn to sign in a user and then call Auth.fetchSession":
            return "再ログイン後に処理を再試行してください。"
        case "Follow the steps to configure AWS Cognito Identity Pool and try again":
            return "AWS Cognito Identity Poolを設定したうえで再試行してください。"
        case "Change password require a user signed in to Auth category, use one of the signIn apis to signIn":
            return "サインイン後にパスワード変更を再実行してください。"
        case "Re-authenticate the user by using one of the signIn apis",
            "Invoke Auth.signIn to re-authenticate the user":
            return "再ログインしてから再試行してください。"
        case "Try again with exponential backoff":
            return "通信状況をご確認のうえ、少し時間をおいて再試行してください。"
        case "SignIn to Auth category by using one of the sign in methods and then try again":
            return "サインイン後に再試行してください。"
        case "Tokens are not valid with user signed in through AWS Cognito Identity Pool":
            return "User Pool経由でサインインし直して再試行してください。"
        case "User sub are not valid with user signed in through AWS Cognito Identity Pool":
            return "User Pool経由でサインインし直して再試行してください。"
        case "Invoke the associate WebAuthn credential flow again":
            return "WebAuthn登録を再実行してください。"
        case "Remove the old WebAuthn credential and try again":
            return "既存のWebAuthn資格情報を削除してから再試行してください。"
        case "Invoke the sign in with WebAuthn flow again":
            return "WebAuthnサインインを再実行してください。"
        case "Make sure that the parameters passed are valid":
            return "入力された値が正しいか確認してください。"
        default:
            return "インターネット接続状況を確認してください。繋がっている場合はしばらく待ってから再試行してください。"
        }
    }

    private static func normalize(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasSuffix(".") {
            value.removeLast()
        }
        return value
    }

    private static func isAuthRelated(description: String) -> Bool {
        let lower = description.lowercased()
        return lower.contains("signed in")
            || lower.contains("session expired")
            || lower.contains("validate the user")
            || lower.contains("incorrect username or password")
            || lower.contains("authorized to perform the operation")
            || lower.contains("change password")
            || lower.contains("fetch attributes")
            || lower.contains("update attributes")
            || lower.contains("confirm attribute")
            || lower.contains("cognito tokens")
            || lower.contains("required to signin")
            || lower.contains("required to signup")
            || lower.contains("required to confirmsignup")
            || lower.contains("required to confirmsignin")
            || lower.contains("required to resetpassword")
            || lower.contains("required to confirmresetpassword")
            || lower.contains("challengeresponse")
    }

    private static func isNetworkRelated(description: String) -> Bool {
        let lower = description.lowercased()
        return lower.contains("network error")
            || lower.contains("cannot connect")
            || lower.contains("timed out")
    }
}
