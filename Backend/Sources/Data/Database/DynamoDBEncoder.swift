//
//  DynamoDBEncoder.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/13.
//

import Foundation
import AWSDynamoDB
import Shared

// MARK: - DynamoDBEncoder
struct DynamoDBEncoder {
    func encode<T: Encodable>(_ value: T) throws -> [String: DynamoDBClientTypes.AttributeValue] {
        let mirror = Mirror(reflecting: value)
        let encoded = try encodeObject(mirror)
        return encoded
    }
    
    private func encodeObject(_ mirror: Mirror) throws -> [String: DynamoDBClientTypes.AttributeValue] {
        var result: [String: DynamoDBClientTypes.AttributeValue] = [:]

        for child in mirror.children {
            guard let label = child.label else { continue }
            let cleanLabel: String = {
                if label.hasPrefix("_") || label.hasPrefix("$") {
                    String(label.dropFirst())
                } else {
                    label
                }
            }()
            let key = snakeCase(cleanLabel)
            var value = child.value
            let childMirror = Mirror(reflecting: value)
            if "\(childMirror.subjectType)".starts(with: "NullEncodable<") {
                if let firstChild = childMirror.children.first {
                    value = firstChild.value
                }
            }
            result[key] = try encodeValue(value)
        }

        return result
    }
    
    func encodeKey(_ key: Any) throws -> DynamoDBClientTypes.AttributeValue {
        switch key {
        case let v as String:
            return .s(v)
        case let v as Int:
            return .n("\(v)")
        case let v as Double:
            return .n("\(v)")
        case let v as Bool:
            return .bool(v)
        default:
            throw NSError(domain: "DynamoDB", code: -1, userInfo: [
                "message": "Unsupported key type: \(type(of: key))"
            ])
        }
    }
    
    private func encodeValue(_ value: Any) throws -> DynamoDBClientTypes.AttributeValue {
        if let unwrapped = unwrapOptional(value) {
            return try encodeNonOptional(unwrapped)
        } else {
            return .null(true)
        }
    }

    private func encodeNonOptional(_ value: Any) throws -> DynamoDBClientTypes.AttributeValue {
        if let e = value as? any RawRepresentable {
            return try encodeNonOptional(e.rawValue)
        }
        if let num = value as? NSNumber {
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                return .bool(num.boolValue)
            }
            let doubleVal = num.doubleValue
            let intVal = num.int64Value
            if Double(intVal) == doubleVal {
                return .n("\(intVal)")
            } else {
                return .n("\(doubleVal)")
            }
        }

        switch value {
        case let v as Bool:
            return .bool(v)
        case let v as Int:
            return .n("\(v)")
        case let v as Int64:
            return .n("\(v)")
        case let v as Double:
            return .n("\(v)")
        case let v as String:
            return .s(v)
        case let v as [Any]:
            return .l(try v.map { try encodeValue($0) })
        case let v as [String: Any]:
            return .m(try v.mapValues { try encodeValue($0) })
        case let v as Encodable:
            let mirror = Mirror(reflecting: v)
            return .m(try encodeObject(mirror))
        default:
            return .s(String(describing: value))
        }
    }
    
    private func unwrapOptional(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle != .optional {
            return value
        }
        if mirror.children.isEmpty {
            return nil
        }
        return mirror.children.first!.value
    }

    private func snakeCase(_ key: String) -> String {
        key.reduce(into: "") { r, c in
            if c.isUppercase { r += "_" + c.lowercased() }
            else { r.append(c) }
        }
    }
}

