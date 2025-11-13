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
        let data = try JSONSerialization.data(withJSONObject: decodeFromAttributes(item))
        return try jsonDecoder.decode(T.self, from: data)
    }
    
    private func decodeFromAttributes(_ item: [String: DynamoDBClientTypes.AttributeValue]) -> [String: Any] {
        var dict: [String: Any] = [:]
        for (k, v) in item {
            switch v {
            case .s(let s): dict[k] = s
            case .n(let n): dict[k] = Double(n) ?? n
            case .bool(let b): dict[k] = b
            case .l(let arr): dict[k] = arr.map { decodeFromAttribute($0) }
            case .m(let map): dict[k] = decodeFromAttributes(map)
            default: dict[k] = nil
            }
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
}
