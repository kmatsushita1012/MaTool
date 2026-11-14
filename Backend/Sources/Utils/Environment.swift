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
    var advertiserCognitoAppClientId: String?
    var advertiserCognitoAppClientSecret: String?
}

extension Environment: DependencyKey{
    static var liveValue: Environment {
        let variables = resolvedVariables()
        guard let poolId = variables["COGNITO_USER_POOL_ID"],
              let email = variables["COGNITO_TEST_EMAIL"] else {
            if ProcessInfo.processInfo.environment["AWS_LAMBDA_FUNCTION_NAME"] != nil {
                fatalError("Lambda環境変数 COGNITO_USER_POOL_ID と COGNITO_TEST_EMAIL を設定してください")
            }
            fatalError("COGNITO_USER_POOL_ID と COGNITO_TEST_EMAIL を環境変数または Backend/.env に設定してください")
        }

        return Environment(
            cognitoPoolId: poolId,
            cognitoTestEmail: email,
            advertiserCognitoAppClientId: variables["COGNITO_ADVERTISER_APP_CLIENT_ID"],
            advertiserCognitoAppClientSecret: variables["COGNITO_ADVERTISER_APP_CLIENT_SECRET"]
        )
    }

    static func resolvedVariables(
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath
    ) -> [String: String] {
        // Lambda の設定値は関数の環境変数を唯一の参照元にする。
        guard processEnvironment["AWS_LAMBDA_FUNCTION_NAME"] == nil else {
            return processEnvironment
        }

        var variables = processEnvironment
        let directory = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
        let environmentFiles = [
            directory.appendingPathComponent(".env"),
            directory.appendingPathComponent("Backend/.env")
        ]
        guard let url = environmentFiles.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return variables
        }

        for (key, value) in parsedValues(in: contents) where variables[key] == nil {
            variables[key] = value
        }
        return variables
    }

    // Internal so the .env parsing rules can be verified without changing process environment.
    static func value(for key: String, in contents: String) -> String? {
        parsedValues(in: contents)[key]
    }

    private static func parsedValues(in contents: String) -> [String: String] {
        var parsed: [String: String] = [:]
        for line in contents.split(whereSeparator: \.isNewline) {
            let line = line.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"),
                  let separator = line.firstIndex(of: "=") else {
                continue
            }

            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            guard parsed[key] == nil else { continue }

            var value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            if value.count >= 2,
               (value.first == "\"" && value.last == "\"") ||
               (value.first == "'" && value.last == "'") {
                value.removeFirst()
                value.removeLast()
            }
            parsed[key] = value
        }

        return parsed
    }
    
    static var testValue: Environment {
        liveValue
    }
}
