//
//  Response.swift
//  matool-shared
//
//  Created by 松下和也 on 2026/02/15.
//

public struct ErrorResponse: Codable {
    public let message: String
    public let localizedDescription: String
    
    public init(message: String, localizedDescription: String) {
        self.message = message
        self.localizedDescription = localizedDescription
    }
}
