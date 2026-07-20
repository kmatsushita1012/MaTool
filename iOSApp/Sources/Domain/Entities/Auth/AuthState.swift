//
//  Result.swift
//  MaTool
//
//  Created by 松下和也 on 2025/06/20.
//

import Shared

enum SignInState: Equatable {
    case signedIn(UserRole)
    case newPasswordRequired
}

enum UpdateEmailState: Equatable {
    case completed
    case verificationRequired(destination: String)
}

enum SignInResponse {
    case success
    case newPasswordRequired
}
