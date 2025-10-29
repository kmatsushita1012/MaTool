//
//  AwsMobileClient.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/20.
//


extension Error {
    func toAuthError() -> AuthError {
        return .unknown(self.localizedDescription)
    }
}

