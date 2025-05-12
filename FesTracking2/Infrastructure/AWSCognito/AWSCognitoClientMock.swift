//
//  AWSCognitoMockClient.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/05.
//

import Dependencies

extension AWSCognitoClient: TestDependencyKey {
    internal static let testValue = Self.noop
    internal static let previewValue = Self.noop
}

extension AWSCognitoClient {
    static let noop = Self(
        initialize: {
            return .success(.district("johoku"))
        },
        signIn: { username,password in
            return .success(.district("johoku"))
        },
        getTokens: {
            return .failure(.unknown("Mock"))
        },
        signOut: {
            return .success(true)
        }
    )
}
