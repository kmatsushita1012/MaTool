//
//  DynamoDBEncoder.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/13.
//

import Foundation
import AWSDynamoDB

// MARK: - DynamoDBEncoder
struct DynamoDBEncoder {
    private let jsonEncoder = JSONEncoder()
    
    func encode<T: Codable>(_ item: T) throws -> [String: DynamoDBClientTypes.AttributeValue] {
        let data = try jsonEncoder.encode(item)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let snakeCased = mapKeysToSnakeCase(json)
        return snakeCased.mapValues { toAttributeValue($0) }
    }
    
    func toAttributeValue(_ value: Any) -> DynamoDBClientTypes.AttributeValue {
        switch value {
        case let v as String: return .s(v)
        case let v as Int: return .n("\(v)")
        case let v as Double: return .n("\(v)")
        case let v as Bool: return .bool(v)
        case let v as [Any]: return .l(v.map { toAttributeValue($0) })
        case let v as [String: Any]: return .m(mapKeysToSnakeCase(v).mapValues { toAttributeValue($0) })
        default: return .s("\(value)")
        }
    }
    
    private func mapKeysToSnakeCase(_ dict: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (k, v) in dict {
            let snakeKey = camelToSnake(k)
            if let subDict = v as? [String: Any] {
                result[snakeKey] = mapKeysToSnakeCase(subDict)
            } else if let arr = v as? [[String: Any]] { // 配列の中が辞書なら再帰
                result[snakeKey] = arr.map { mapKeysToSnakeCase($0) }
            } else {
                result[snakeKey] = v
            }
        }
        return result
    }

    
    private func camelToSnake(_ key: String) -> String {
        var result = ""
        for char in key {
            if char.isUppercase {
                result.append("_\(char.lowercased())")
            } else {
                result.append(char)
            }
        }
        return result
    }
}

