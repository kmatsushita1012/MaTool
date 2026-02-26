//
//  DynamoDBDecoder.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Foundation
import AWSDynamoDB

// MARK: - DynamoDBDecoder
struct DynamoDBDecoder {

    private let jsonDecoder: JSONDecoder

    init() {
        let dec = JSONDecoder()
        // ✅ snake_case -> camelCase をここで自動変換
        dec.keyDecodingStrategy = .convertFromSnakeCase
        self.jsonDecoder = dec
    }

    func decode<T: Decodable>(
        _ item: [String: DynamoDBClientTypes.AttributeValue],
        as type: T.Type
    ) throws -> T {

        let dict = decodeAttributesToJSONObject(item)   // snake_case keys のまま
        let data = try JSONSerialization.data(withJSONObject: dict, options: [])
        return try jsonDecoder.decode(T.self, from: data)
    }
    
    // MARK: - AttributeValue -> JSON object graph

    private func decodeAttributesToJSONObject(
        _ item: [String: DynamoDBClientTypes.AttributeValue]
    ) -> [String: Any] {

        var dict: [String: Any] = [:]
        dict.reserveCapacity(item.count)

        for (k, v) in item {
            dict[k] = decodeAttributeToAny(v)
        }
        return dict
    }
    
    private func decodeAttributeToAny(_ value: DynamoDBClientTypes.AttributeValue) -> Any {
        switch value {
        case .s(let s):
            return s
        case .n(let n):
            if let i = Int(n) { return i }
            if let d = Double(n) { return d }
            return n
        case .bool(let b):
            return b
        case .l(let arr):
            return arr.map(decodeAttributeToAny)
        case .m(let map):
            return decodeAttributesToJSONObject(map)
        case .null:
            return NSNull()
        default:
            return NSNull()
        }
    }
}
