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
    private let jsonDecoder = JSONDecoder()
    
    func decode<T: Codable>(_ item: [String: DynamoDBClientTypes.AttributeValue], as type: T.Type) throws -> T {
        let decodedDict = decodeFromAttributes(item)
        let data = try JSONSerialization.data(withJSONObject: decodedDict)
        return try jsonDecoder.decode(T.self, from: data)
    }
    
    private func decodeFromAttributes(_ item: [String: DynamoDBClientTypes.AttributeValue]) -> [String: Any] {
        var dict: [String: Any] = [:]
        for (k, v) in item {
            let camelKey = snakeToCamel(k) // ← ここで変換
            dict[camelKey] = decodeFromAttribute(v)
        }
        return dict
    }
    
    private func decodeFromAttribute(_ value: DynamoDBClientTypes.AttributeValue) -> Any {
        switch value {
        case .s(let s): return s
        case .n(let n): return Double(n) ?? n
        case .bool(let b): return b
        case .l(let arr): return arr.map { decodeFromAttribute($0) }
        case .m(let map): return decodeFromAttributes(map)
        default: return NSNull()
        }
    }
    
    private func snakeToCamel(_ key: String) -> String {
        let parts = key.split(separator: "_")
        let first = parts.first?.lowercased() ?? ""
        let rest = parts.dropFirst().map { $0.capitalized }
        return ([first] + rest).joined()
    }
}
