//
//  AuthError.swift
//  MaTool
//
//  Created by 松下和也 on 2025/06/19.
//

import Foundation
import Amplify

extension AppError {
    static func parseAuth(_ error: Error, operation: String) -> AppError? {
        if let appError = error as? AppError {
            return appError
        }

        if let amplifyError = error as? any AmplifyError {
            let description = amplifyError.errorDescription
            let recovery = amplifyError.recoverySuggestion
            let message = localizedAmplifyMessage(
                description: description,
                recovery: recovery
            )

            if isAuthRelated(description: description) {
                return .auth(.unauthorized(message))
            }
            if isNetworkRelated(description: description) {
                return .auth(.network(message))
            }
            return .auth(.unknown(message))
        }

        if error is CancellationError {
            return .auth(.timeout(operation))
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .auth(.timeout(operation))
            case NSURLErrorNotConnectedToInternet,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorDNSLookupFailed:
                return .auth(.network(composeMessage(
                    main: "通信環境が不安定なため処理に失敗しました。",
                    recovery: "通信状況をご確認のうえ、時間をおいて再試行してください。"
                )))
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
        default:
            return description
        }
    }

    private static func localizedAmplifyRecovery(_ recovery: String) -> String {
        recovery
    }

    private static func isAuthRelated(description: String) -> Bool {
        let value = normalize(description)
        return value.contains("password")
            || value.contains("username")
            || value.contains("sign")
            || value.contains("session")
            || value.contains("credential")
            || value.contains("token")
            || value.contains("auth")
    }

    private static func isNetworkRelated(description: String) -> Bool {
        let value = normalize(description)
        return value.contains("network")
            || value.contains("connection")
            || value.contains("timeout")
            || value.contains("host")
    }

    private static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
