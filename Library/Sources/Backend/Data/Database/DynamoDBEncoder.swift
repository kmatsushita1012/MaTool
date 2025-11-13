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
        return json.mapValues { toAttributeValue($0) }
    }
    
    func toAttributeValue(_ value: Any) -> DynamoDBClientTypes.AttributeValue {
        switch value {
        case let v as String: return .s(v)
        case let v as Int: return .n("\(v)")
        case let v as Double: return .n("\(v)")
        case let v as Bool: return .bool(v)
        case let v as [Any]: return .l(v.map { toAttributeValue($0) })
        case let v as [String: Any]: return .m(v.mapValues { toAttributeValue($0) })
        default: return .s("\(value)")
        }
    }
}
