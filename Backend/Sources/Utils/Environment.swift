//
//  Environment.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/22.
//

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

        if let envPoolId = ProcessInfo.processInfo.environment["COGNITO_USER_POOL_ID"],
           let envEmail  = ProcessInfo.processInfo.environment["COGNITO_TEST_EMAIL"] {
            poolId = envPoolId
            email  = envEmail
        } else {
            // ローカル開発：.env ファイルから読み込む場合
            guard let url = Bundle.module.url(forResource: ".env", withExtension: nil) else {
                fatalError(".env ファイルを取得できません")
            }
            
            guard let contents = try? String(contentsOf: url, encoding: .utf8),
                  let filePoolId = Self.value(for: "COGNITO_USER_POOL_ID", in: contents),
                  let fileEmail = Self.value(for: "COGNITO_TEST_EMAIL", in: contents) else {
                fatalError(".env ファイルから環境変数を取得できません")
            }
            poolId = filePoolId
            email  = fileEmail
        }
        return Environment(
            cognitoPoolId: poolId,
            cognitoTestEmail: email
        )
    }

    private static func value(for key: String, in contents: String) -> String? {
        for line in contents.split(whereSeparator: \.isNewline) {
            let line = line.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"),
                  let separator = line.firstIndex(of: "=") else {
                continue
            }

            let candidateKey = line[..<separator].trimmingCharacters(in: .whitespaces)
            guard candidateKey == key else { continue }

            var value = line[line.index(after: separator)...]
                .trimmingCharacters(in: .whitespaces)
            if value.count >= 2,
               (value.first == "\"" && value.last == "\"") ||
               (value.first == "'" && value.last == "'") {
                value.removeFirst()
                value.removeLast()
            }
            return value
        }
        return nil
    }
    
    static var testValue: Environment {
        liveValue
    }
}
