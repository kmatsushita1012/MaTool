//
//  SignInResult.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/06/20.
//

enum SignInResult: Equatable {
    case success(UserRole)
    case newPasswordRequired
    case failure(AuthError)
}
