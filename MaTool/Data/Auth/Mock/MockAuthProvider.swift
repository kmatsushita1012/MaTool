//
//  AWSCognitoMockClient.swift
//  MaTool
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
            return .success(Empty())
        },
        signIn: { _, _ in
            return .success
        },
        confirmSignIn: { _ in
            return .success(Empty())
        },
        getUserRole: {
            return .success(.district("祭_町"))
        },
        getTokens: {
            return .failure(.unknown("Mock"))
        },
        signOut: {
            return .success(Empty())
        },
        changePassword: { _, _ in
            return .success(Empty())
            
        },
        resetPassword: { _ in
            return .success(Empty())
        },
        confirmResetPassword: { _, _, _ in
            return .success(Empty())
        },
        updateEmail: { _ in
            return .verificationRequired(destination: "sample@email.com")
        },
        confirmUpdateEmail: { _ in
            return .success(Empty())
        }
    )
}
