//
//  AuthProvider.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/05.
//

import AWSMobileClient
import Dependencies

enum AuthSignInResult: Equatable {
    case success
    case newPasswordRequired
    case failure(AuthError)
}


final class AWSCognitoAccessTokenStore {
    var value: String?
}

extension DependencyValues {
    var accessToken: AWSCognitoAccessTokenStore {
        get { self[AWSCognitoAccessTokenStore.self] }
        set { self[AWSCognitoAccessTokenStore.self] = newValue }
    }
}


