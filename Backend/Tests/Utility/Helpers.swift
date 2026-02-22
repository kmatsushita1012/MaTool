//
//  Helpers.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/04.
//

import Foundation

func makeDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int = 0,
    minute: Int = 0,
    second: Int = 0
) -> Date {
    return Date.combine(date: .init(year: year, month: month, day: day), time: .init(hour: hour, minute: minute))
}

func decodeFromEncodable<T: Decodable>(_ item: any Encodable, as type: T.Type = T.self) throws -> T {
    let data = try JSONEncoder().encode(AnyEncodable(item))
    return try JSONDecoder().decode(T.self, from: data)
}

func encodeForDataStore(_ items: any Encodable) throws -> Data {
    try JSONEncoder().encode(AnyEncodable(items))
}

private struct AnyEncodable: Encodable {
    private let encodeImpl: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        self.encodeImpl = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeImpl(encoder)
    }
}
