//
//  AWSCognitoMockClient.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/05.
//

import Dependencies

extension AuthProvider: TestDependencyKey {
    internal static let testValue = Self.noop
    internal static let previewValue = Self.noop
}

extension AuthProvider {
    static let noop = Self(
        initialize: {
            return .success("Success")
        },
        signIn: { username, password in
            return .success
        },
        confirmSignIn: { newPassword in
            return .success("Success")
        },
        getUserRole: {
            return .success(.district("祭_町"))
        },
        getTokens: {
            return .failure(.unknown("Mock"))
        },
        signOut: {
            return .success(true)
        }
    )
}
