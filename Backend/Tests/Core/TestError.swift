//
//  TestError.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/24.
//


enum TestError: Error, Equatable, Sendable{
    case unimplemented
    case intentional
    case typeUnmatched(expected: String, actual: String)
    
    static func typeUnmatched(expected: Any.Type, actual: Any.Type) -> Self{
        .typeUnmatched(expected: "\(expected)", actual: "\(actual)")
    }
}
