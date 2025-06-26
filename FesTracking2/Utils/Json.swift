//
//  Json.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/06/26.
//

@propertyWrapper
struct NullEncodable<T: Codable>: Codable{

    var wrappedValue: T?

    init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch wrappedValue {
        case .some(let value): try container.encode(value)
        case .none: try container.encodeNil()
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try? container.decode(T.self)
    }
}

extension NullEncodable: Equatable where T: Equatable {}
extension NullEncodable: Hashable where T: Hashable {}
