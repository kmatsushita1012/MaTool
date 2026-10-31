//
//  Result.swift
//  MaTool
//
//  Created by 松下和也 on 2025/06/20.
//

import Shared

enum SignInState: Equatable, Sendable {
    case signedIn(UserRole)
    case newPasswordRequired
}

enum UpdateEmailState: Equatable, Sendable {
    case completed
    case verificationRequired(destination: String)
}

enum SignInResponse: Sendable {
    case success
    case newPasswordRequired
}
