//
//  AwsMobileClient.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/20.
//

import AWSMobileClient

extension AWSMobileClientError {
    var text: String {
        switch self {
        case .aliasExists:
            return "このメールアドレスはすでに使われています。"
        case .codeDeliveryFailure:
            return "確認コードの送信に失敗しました。"
        case .codeMismatch:
            return "確認コードが正しくありません。"
        case .expiredCode:
            return "確認コードの有効期限が切れています。"
        case .groupExists:
            return "指定されたグループはすでに存在します。"
        case .internalError:
            return "内部エラーが発生しました。もう一度お試しください。"
        case .invalidLambdaResponse:
            return "サーバーから無効なレスポンスが返されました。"
        case .invalidOAuthFlow:
            return "OAuth フローが無効です。"
        case .invalidParameter (let message):
            if message == "Cannot reset password for the user as there is no registered/verified email or phone_number"{
                return "メールアドレスが認証されていません。管理者にお問い合わせください。"
            } else {
                return "入力された情報に不備があります。"
            }
        case .invalidPassword:
            return "パスワードが無効です。要件を確認してください。"
        case .invalidUserPoolConfiguration:
            return "ユーザープールの設定に誤りがあります。"
        case .limitExceeded:
            return "リクエストの制限を超えました。しばらくしてからお試しください。"
        case .mfaMethodNotFound:
            return "多要素認証方法が見つかりません。"
        case .notAuthorized:
            return "IDもしくはパスワードが間違っています"
        case .passwordResetRequired:
            return "パスワードのリセットが必要です。"
        case .resourceNotFound:
            return "指定されたリソースが見つかりませんでした。"
        case .scopeDoesNotExist:
            return "指定されたスコープは存在しません。"
        case .softwareTokenMFANotFound:
            return "ソフトウェアトークンによる多要素認証が設定されていません。"
        case .tooManyFailedAttempts:
            return "失敗した試行が多すぎます。しばらく待ってから再試行してください。"
        case .tooManyRequests:
            return "リクエストが多すぎます。時間をおいて再試行してください。"
        case .unexpectedLambda:
            return "予期しないエラーが発生しました。"
        case .userLambdaValidation:
            return "ユーザーの検証に失敗しました。"
        case .userNotConfirmed:
            return "ユーザーが確認されていません。メールを確認してください。"
        case .userNotFound:
            return "ユーザーが見つかりません。"
        case .usernameExists:
            return "このユーザー名はすでに使われています。"
        case .unknown:
            return "不明なエラーが発生しました。"
        case .notSignedIn:
            return "サインインしていません。"
        case .identityIdUnavailable:
            return "IDを取得できませんでした。"
        case .guestAccessNotAllowed:
            return "ゲストアクセスは許可されていません。"
        case .federationProviderExists:
            return "Federationプロバイダがすでに存在しています。"
        case .cognitoIdentityPoolNotConfigured:
            return "Cognito Identity Pool が設定されていません。"
        case .unableToSignIn:
            return "サインインできませんでした。"
        case .invalidState:
            return "アプリの状態が無効です。"
        case .userPoolNotConfigured:
            return "ユーザープールが設定されていません。"
        case .userCancelledSignIn:
            return "サインインがキャンセルされました。"
        case .badRequest:
            return "不正なリクエストです。"
        case .expiredRefreshToken:
            return "ログインの有効期限が切れています。再度サインインしてください。"
        case .errorLoadingPage:
            return "ページの読み込みに失敗しました。"
        case .securityFailed:
            return "セキュリティチェックに失敗しました。"
        case .idTokenNotIssued:
            return "IDトークンが発行されませんでした。"
        case .idTokenAndAcceessTokenNotIssued:
            return "IDトークンおよびアクセストークンが発行されませんでした。"
        case .invalidConfiguration:
            return "設定に誤りがあります。"
        case .deviceNotRemembered:
            return "このデバイスは認識されていません。"
        }
    }
}
extension AWSMobileClientError {
    func toAuthError() -> AuthError {
        return .auth(self.text)
    }
}

extension Error {
    func toAuthError() -> AuthError {
        if let aws = self as? AWSMobileClientError {
            return aws.toAuthError()
        } else {
            return .unknown(self.localizedDescription)
        }
    }
}

