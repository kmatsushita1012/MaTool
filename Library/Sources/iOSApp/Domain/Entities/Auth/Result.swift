//
//  Result.swift
//  MaTool
//
//  Created by 松下和也 on 2025/06/20.
//

import Shared

enum SignInResult: Equatable {
    case success(UserRole)
    case newPasswordRequired
    case failure(AuthError)
}

enum UpdateEmailResult: Equatable {
    case completed
    case verificationRequired(destination: String)
    case failure(AuthError)
}


enum InitializeResult: Equatable {
    case signedIn
    case signedOut
}

extension Error {
    func toAuthError() -> AuthError {
        return .unknown(self.localizedDescription)
    }
}

enum SignInResponse {
    case success
    case newPasswordRequired
    case failure(AuthError)
}

