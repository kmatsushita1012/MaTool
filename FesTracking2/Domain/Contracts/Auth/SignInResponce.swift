//
//  SignInResponce.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/06/20.
//

enum SignInResponse {
    case success
    case newPasswordRequired
    case failure(AuthError)
}
