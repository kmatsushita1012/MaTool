import AWSCognitoAuthPlugin

extension AppError {
    static func localizedCognitoServiceError(_ error: Error?) -> AppError? {
        guard let cognitoError = error as? AWSCognitoAuthError else {
            return nil
        }

        switch cognitoError {
        case .userNotFound:
            return .auth(.unauthorized("ユーザーが見つかりません。"))
        case .userNotConfirmed:
            return .auth(.unauthorized("ユーザー登録の確認が完了していません。"))
        case .usernameExists:
            return .auth(.conflict("このユーザー名は既に使用されています。"))
        case .aliasExists:
            return .auth(.conflict("このメールアドレスは既に使用されています。"))
        case .codeDelivery:
            return .auth(.badRequest("確認コードを送信できませんでした。"))
        case .codeMismatch:
            return .auth(.badRequest("確認コードが正しくありません。"))
        case .codeExpired:
            return .auth(.badRequest("確認コードの有効期限が切れています。もう一度コードを送信してください。"))
        case .invalidParameter:
            return .auth(.badRequest("入力内容が正しくありません。"))
        case .invalidPassword:
            return .auth(.unauthorized("パスワードが正しくありません。"))
        case .limitExceeded:
            return .auth(.unknown("利用上限に達しました。しばらくしてから再試行してください。"))
        case .mfaMethodNotFound:
            return .auth(.configuration("MFAの認証方法が見つかりません。"))
        case .softwareTokenMFANotEnabled:
            return .auth(.configuration("ソフトウェアトークンMFAが有効になっていません。"))
        case .passwordResetRequired:
            return .auth(.unauthorized("パスワードの再設定が必要です。"))
        case .resourceNotFound:
            return .auth(.configuration("認証に必要なリソースが見つかりません。"))
        case .failedAttemptsLimitExceeded:
            return .auth(.unknown("認証の試行回数が上限に達しました。しばらくしてから再試行してください。"))
        case .requestLimitExceeded:
            return .auth(.unknown("リクエスト回数の上限に達しました。しばらくしてから再試行してください。"))
        case .lambda:
            return .auth(.unknown("認証サービスの処理に失敗しました。"))
        case .deviceNotTracked:
            return .auth(.unknown("この端末は認証デバイスとして登録されていません。"))
        case .errorLoadingUI:
            return .auth(.unknown("認証画面の読み込みに失敗しました。"))
        case .userCancelled:
            return .auth(.cancelled("認証操作がキャンセルされました。"))
        case .invalidAccountTypeException:
            return .auth(.configuration("現在のアカウント設定ではこの操作を利用できません。"))
        case .network:
            return .auth(.network("通信エラーが発生しました。通信状況を確認して再試行してください。"))
        case .smsRole:
            return .auth(.configuration("SMS送信設定に問題があります。"))
        case .emailRole:
            return .auth(.configuration("メール送信設定に問題があります。"))
        case .externalServiceException:
            return .auth(.unknown("外部認証サービスとの通信に失敗しました。"))
        case .limitExceededException:
            return .auth(.unknown("ユーザープールの上限に達しました。"))
        case .resourceConflictException:
            return .auth(.conflict("このログイン情報は別のアカウントに関連付けられています。"))
        case .webAuthnChallengeNotFound:
            return .auth(.badRequest("WebAuthnの認証要求が見つかりません。"))
        case .webAuthnClientMismatch:
            return .auth(.configuration("このアプリクライアントはパスキー認証に対応していません。"))
        case .webAuthnNotSupported:
            return .auth(.configuration("この端末はパスキー認証に対応していません。"))
        case .webAuthnNotEnabled:
            return .auth(.configuration("WebAuthnが有効になっていません。"))
        case .webAuthnOriginNotAllowed:
            return .auth(.configuration("この端末の認証元は許可されていません。"))
        case .webAuthnRelyingPartyMismatch:
            return .auth(.configuration("WebAuthnの認証先が一致しません。"))
        case .webAuthnConfigurationMissing:
            return .auth(.configuration("WebAuthnの設定が不足しています。"))
        }
    }
}
