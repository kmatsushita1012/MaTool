//
//  Environment.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/22.
//

import SwiftDotenv
import Dependencies
import Foundation

struct Environment: Sendable {
    var cognitoPoolId: String
    var cognitoTestEmail: String
}

extension Environment: DependencyKey{
    static var liveValue: Environment {
        let poolId: String
        let email: String
        
        #if DEBUG
        do {
            // このファイルのパス
            let fileURL = URL(fileURLWithPath: #filePath)
            // Sources/Backend/Core/Environment.swift なら
            let projectRoot = fileURL.deletingLastPathComponent() // Environment.swift
                                     .deletingLastPathComponent() // Core
                                     .deletingLastPathComponent() // Sources
            let envPath = projectRoot.appendingPathComponent(".env").path
            
            print("Loading .env from:", envPath)
            try Dotenv.configure(atPath: envPath)
        } catch {
            print("Failed to load .env:", error)
        }
        #endif

        if let envPoolId = ProcessInfo.processInfo.environment["COGNITO_USER_POOL_ID"],
           let envEmail  = ProcessInfo.processInfo.environment["COGNITO_TEST_EMAIL"] {
            print("Get env value from ProcessInfo")
            poolId = envPoolId
            email  = envEmail
        } else {
            // ローカル開発：.env ファイルから読み込む場合
            print(".env ファイルを取得できません")
//            guard let url = Bundle.module.url(forResource: ".env", withExtension: nil) else {
//                fatalError(".env ファイルを取得できません")
//            }
//            
//            guard let _ = try? Dotenv.configure(atPath: url.path()) else {
//                fatalError("Dotenv.configure に失敗しました")
//            }
//            guard let filePoolId = Dotenv["COGNITO_USER_POOL_ID"]?.stringValue,
//                  let fileEmail  = Dotenv["COGNITO_TEST_EMAIL"]?.stringValue else {
//                fatalError(".env ファイルから環境変数を取得できません")
//            }
//            print("Get env value from Dotenv")
//            poolId = filePoolId
//            email  = fileEmail
            poolId = ""
            email  = ""
        }
        return Environment(
            cognitoPoolId: poolId,
            cognitoTestEmail: email
        )
    }
    
    static var testValue: Environment {
        liveValue
    }
}

