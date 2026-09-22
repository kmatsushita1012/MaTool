//
//  Result.swift
//  MaTool
//
//  Created by 松下和也 on 2025/06/20.
//

import Shared

public enum SignInState: Equatable, Sendable {
    case signedIn(UserRole)
    case newPasswordRequired
}

public enum UpdateEmailState: Equatable, Sendable {
    case completed
    case verificationRequired(destination: String)
}

public enum SignInResponse: Sendable {
    case success
    case newPasswordRequired
}
