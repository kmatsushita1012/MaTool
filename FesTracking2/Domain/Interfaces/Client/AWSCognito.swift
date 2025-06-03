//
//  AWSCognitoClient.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/05.
//

import AWSMobileClient
import Dependencies

struct AWSCognito {
    struct Client {
        var initialize: () async -> Result<UserRole,AWSCognitoError>
        var signIn: (_ username: String, _ password: String) async -> Result<UserRole,AWSCognitoError>
        var changePassword() ->
        var getTokens: () async -> Result<Tokens,AWSCognitoError>
        var signOut: () async -> Result<Bool,AWSCognitoError>
    }
    
    enum SignInState
    
    
    enum AWSCognitoError: Error, Equatable {
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
  var awsCognitoClient: AWSCognitoClient {
    get { self[AWSCognitoClient.self] }
    set { self[AWSCognitoClient.self] = newValue }
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


