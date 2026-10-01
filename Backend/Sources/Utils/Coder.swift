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

extension Encodable {
    func toString() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data: Data = try encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }
}

extension Decodable {
    static func from(_ string: String) throws -> Self {
        let data = Data(string)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(Self.self, from: data)
    }
}

extension LosslessStringConvertible {
    static func from(_ string: String) throws -> Self {
        if let value = Self(string) {
            return value
        } else {
            throw Error.decodingError("文字列 '\(string)' を \(Self.self) に変換できませんでした。")
        }
    }
}
