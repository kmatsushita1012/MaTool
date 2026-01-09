//
//  Error.swift
//  matool-shared
//
//  Created by 松下和也 on 2026/01/09.
//

public enum SharedError: Error, Equatable, Hashable {
    case unknown(message: String)
    
    public init(_ error: Error) {
        self = .unknown(message: error.localizedDescription)
    }
}
