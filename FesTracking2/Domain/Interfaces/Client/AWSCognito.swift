//
//  AWSCognito.Client.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/05.
//

import AWSMobileClient
import Dependencies

struct AWSCognito: Equatable {
    struct Client {
        var initialize: () async -> Result<String,Error>
        var signIn: (_ username: String, _ password: String) async -> SignInResult
        var confirmSignIn: (_ newPassword: String) async -> Result<String, Error>
        var getUserRole: () async -> Result<UserRole,Error>
        var getTokens: () async -> Result<Tokens,Error>
        var signOut: () async -> Result<Bool,Error>
    }
    
    enum SignInResult: Equatable {
        case success
        case newPasswordRequired
        case failure(Error)
    }
    
    
    enum Error: Swift.Error, Equatable {
        case network(String)
        case encoding(String)
        case decoding(String)
        case unknown(String)
        
        var localizedDescription: String {
            switch self {
            case .network(let message):
                return "Network Error: \(message)"
            case .encoding(let message):
                return "Encoding Error: \(message)"
            case .decoding(let message):
                return "Decoding Error: \(message)"
            case .unknown(let message):
                return "Unknown Error: \(message)"
            }
        }
    }
}

extension DependencyValues {
  var awsCognitoClient: AWSCognito.Client {
    get { self[AWSCognito.Client.self] }
    set { self[AWSCognito.Client.self] = newValue }
  }
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


