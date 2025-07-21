//
//  UpdateEmailResult.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/17.
//

enum UpdateEmailResult: Equatable {
    case completed
    case verificationRequired(destination: String)
    case failure(AuthError)
}
