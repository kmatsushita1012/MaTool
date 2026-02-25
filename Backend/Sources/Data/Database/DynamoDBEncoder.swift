//
//  DynamoDBEncoder.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/01.
//

import Foundation
import CoreFoundation
import AWSDynamoDB
import Shared

struct DynamoDBEncoder {

    func encode<T: Encodable>(_ object: T) throws -> [String: DynamoDBClientTypes.AttributeValue] {

        // ① Codable → Data
        let data = try JSONEncoder().encode(object)

        // ② Data → Any (JSONオブジェクト)
        let jsonObject = try JSONSerialization.jsonObject(with: data)

        guard let dictionary = jsonObject as? [String: Any] else {
            throw NSError(domain: "DynamoDBEncoder",
                          code: -1,
                          userInfo: ["message": "Top-level JSON must be dictionary"])
        }

        // ③ Any → DynamoDB AttributeValue
        return try dictionary.mapValues { try convertToAttributeValue($0) }
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

    // MARK: - 再帰変換
    private func convertToAttributeValue(_ value: Any) throws -> DynamoDBClientTypes.AttributeValue {

        switch value {

        case let v as String:
            return .s(v)

        case let v as Int:
            return .n(String(v))

        case let v as Double:
            return .n(String(v))

        case let v as NSNumber:
            // BoolとNumberを区別
            if CFGetTypeID(v) == CFBooleanGetTypeID() {
                return .bool(v.boolValue)
            } else {
                return .n(v.stringValue)
            }

        case let v as Bool:
            return .bool(v)

        case let v as [Any]:
            return .l(try v.map { try convertToAttributeValue($0) })

        case let v as [String: Any]:
            return .m(try v.mapValues { try convertToAttributeValue($0) })

        case _ as NSNull:
            return .null(true)

        default:
            throw NSError(domain: "DynamoDBEncoder",
                          code: -1,
                          userInfo: ["message": "Unsupported type: \(type(of: value))"])
        }
    }
}

//// MARK: - DynamoDBEncoder
//struct DynamoDBEncoder {
//    
//    func encode<T: Encodable>(_ object: T) throws -> [String: DynamoDBClientTypes.AttributeValue] {
//        let data = try JSONEncoder().encode(object)
//        guard let jsonString = String(data: data, encoding: .utf8) else {
//            throw NSError(domain: "DynamoDBEncoder", code: -1,
//                          userInfo: ["message": "Cannot encode object to JSON string"])
//        }
//        return try parseTopLevelObject(jsonString)
//    }
//    
//    func encodeKey(_ key: Any) throws -> DynamoDBClientTypes.AttributeValue {
//        switch key {
//        case let v as String:
//            return .s(v)
//        case let v as Int:
//            return .n("\(v)")
//        case let v as Double:
//            return .n("\(v)")
//        case let v as Bool:
//            return .bool(v)
//        default:
//            throw NSError(domain: "DynamoDB", code: -1, userInfo: [
//                "message": "Unsupported key type: \(type(of: key))"
//            ])
//        }
//    }
//
//    // MARK: - トップレベルは必ずオブジェクト
//    private func parseTopLevelObject(_ json: String) throws -> [String: DynamoDBClientTypes.AttributeValue] {
//        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard trimmed.hasPrefix("{") && trimmed.hasSuffix("}") else {
//            throw NSError(domain: "DynamoDBEncoder", code: -1,
//                          userInfo: ["message": "Top-level JSON must be an object"])
//        }
//        let inner = trimmed.dropFirst().dropLast()
//        var result: [String: DynamoDBClientTypes.AttributeValue] = [:]
//        let elements = splitTopLevelJSONElements(String(inner))
//        for el in elements {
//            let pair = try splitKeyValue(el)
//            result[pair.key] = try parseValue(pair.value)
//        }
//
//        return result
//    }
//
//    // MARK: - 任意の値を解析
//    private func parseValue(_ s: String) throws -> DynamoDBClientTypes.AttributeValue {
//        let str = s.trimmingCharacters(in: .whitespacesAndNewlines)
//
//        if str.hasPrefix("{") && str.hasSuffix("}") {
//            // ネストオブジェクト
//            let inner = str.dropFirst().dropLast()
//            var map: [String: DynamoDBClientTypes.AttributeValue] = [:]
//            let elements = splitTopLevelJSONElements(String(inner))
//            for el in elements {
//                let pair = try splitKeyValue(el)
//                map[pair.key] = try parseValue(pair.value)
//            }
//            return .m(map)
//        }
//
//        if str.hasPrefix("[") && str.hasSuffix("]") {
//            // 配列
//            let inner = str.dropFirst().dropLast()
//            let items = splitTopLevelJSONElements(String(inner))
//            return .l(try items.map { try parseValue($0) })
//        }
//
//        // プリミティブ値
//        let lower = str.lowercased()
//        switch lower {
//        case "true": return .bool(true)
//        case "false": return .bool(false)
//        case "null": return .null(true)
//        default:
//            if Int(str) != nil { return .n(str) }
//            if Double(str) != nil { return .n(str) }
//            if str.hasPrefix("\"") && str.hasSuffix("\"") {
//                return .s(String(str.dropFirst().dropLast()))
//            }
//            // 無引用文字列は文字列として扱う
//            return .s(str)
//        }
//    }
//
//    // MARK: - JSONの "key": value を分割
//    private func splitKeyValue(_ s: String) throws -> (key: String, value: String) {
//        let pattern = #"^\s*"([^"]+)"\s*:\s*(.*)$"#
//        let regex = try NSRegularExpression(pattern: pattern)
//        let nsrange = NSRange(s.startIndex..<s.endIndex, in: s)
//        guard let match = regex.firstMatch(in: s, options: [], range: nsrange),
//              let keyRange = Range(match.range(at: 1), in: s),
//              let valueRange = Range(match.range(at: 2), in: s) else {
//            throw NSError(domain: "DynamoDBEncoder", code: -1, userInfo: ["message": "Invalid JSON key-value: \(s)"])
//        }
//        let key = snakeCase(String(s[keyRange]))
//        let value = String(s[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
//        return (key, value)
//    }
//
//    // MARK: - 配列のトップレベル要素を分割（ネスト考慮）
//    private func splitTopLevelJSONElements(_ s: String) -> [String] {
//        var result: [String] = []
//        var depth = 0
//        var start = s.startIndex
//        var inString = false
//        var escape = false
//
//        for (i, c) in s.enumerated() {
//            let idx = s.index(s.startIndex, offsetBy: i)
//            if c == "\\" && !escape { escape = true; continue }
//            if c == "\"" && !escape { inString.toggle() }
//            escape = false
//            if inString { continue }
//
//            if c == "{" || c == "[" { depth += 1 }
//            if c == "}" || c == "]" { depth -= 1 }
//
//            if c == "," && depth == 0 {
//                let substr = s[start..<idx].trimmingCharacters(in: .whitespacesAndNewlines)
//                result.append(String(substr))
//                start = s.index(after: idx)
//            }
//        }
//        let last = s[start..<s.endIndex].trimmingCharacters(in: .whitespacesAndNewlines)
//        if !last.isEmpty { result.append(String(last)) }
//        return result
//    }
//    
//    private func snakeCase(_ key: String) -> String {
//        key.reduce(into: "") { r, c in
//            if c.isUppercase { r += "_" + c.lowercased() }
//            else { r.append(c) }
//        }
//    }
//}
