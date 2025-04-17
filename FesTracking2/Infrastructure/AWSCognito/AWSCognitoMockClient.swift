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
