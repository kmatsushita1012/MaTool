//
//  Request+.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/24.
//

extension Application.Request {
    func body<T: Decodable>(as type: T.Type) throws -> T {
        guard let body else { throw Error.badRequest("送信されたデータが不十分です。") }
        guard let object: T = try? type.from(body) else {
            throw Error.decodingError("デコードに失敗しました。")
        }
        return object
    }
    
    func parameter<T: LosslessStringConvertible>(_ key: String, as type: T.Type) throws -> T {
        guard let parameter = parameters[key], let value: T = try? type.from(parameter) else {
            throw Error.badRequest("送信されたデータが不十分です。")
        }
        return value
    }
}
