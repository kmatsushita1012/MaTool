//
//  Environment.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/22.
//

import SwiftDotenv
import Dependencies
import Foundation

struct Environment {
    var cognitoPoolId: String
    var cognitoTestEmail: String
}

extension Environment: DependencyKey{
    static var liveValue: Environment {
        let url = Bundle.module.url(forResource: ".env", withExtension: nil)!
        try! Dotenv.configure(atPath: url.path())
        let poolId = Dotenv["COGNITO_USER_POOL_ID"]?.stringValue
        let email = Dotenv["COGNITO_TEST_EMAIL"]?.stringValue
        guard let poolId, let email else { fatalError("Faild to load .env") }
        return Environment(
            cognitoPoolId: poolId,
            cognitoTestEmail: email
        )
    }
    
    static var testValue: Environment {
        liveValue
    }
}

