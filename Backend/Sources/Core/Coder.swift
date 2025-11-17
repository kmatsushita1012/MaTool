//
//  Coder.swift
//  MaToolAPI
//
//  Created by 松下和也 on 2025/10/28.
//

import Foundation

extension Data {
    init(_ string: String) {
        self = string.data(using: .utf8)!
    }
}

func encode<T: Encodable>(_ value: T) throws -> Data {
    try JSONEncoder().encode(value)
}

func encode<T: Encodable>(_ value: T) throws -> String {
    let data: Data = try encode(value)
    return String(data: data, encoding: .utf8)!
}

func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
    try JSONDecoder().decode(T.self, from: data)
}

func decode<T: Decodable>(_ type: T.Type, _ string: String) throws -> T {
    let data = Data(string)
    return try decode(type, data)
}
