//
//  AuthProviderMock.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/05.
//

import Dependencies
import Shared
@testable import iOSApp

extension AuthProvider {
    static let testValue = Self.noop
    static let previewValue = Self.noop
}

extension AuthProvider {
    static let noop = Self(
        initialize: {
            return
        },
        signIn: { _, _ in
            return .success
        },
        confirmSignIn: { _ in
            return ()
        },
        getUserRole: {
            return .district("祭_町")
        },
        getTokens: {
            throw AuthError.unknown("Mock")
        },
        signOut: {
            return ()
        },
        changePassword: { _, _ in
            return ()
            
        },
        resetPassword: { _ in
            return ()
        },
        confirmResetPassword: { _, _, _ in
            return ()
        },
        updateEmail: { _ in
            return .verificationRequired(destination: "sample@email.com")
        },
        confirmUpdateEmail: { _ in
            return ()
        }
    )
}
