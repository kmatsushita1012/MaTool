//
//  SimpleDate+SQLite.swift
//  matool-shared
//
//  Created by 松下和也 on 2026/01/15.
//

import SQLiteData
public extension SimpleDate {
    struct ISODateRepresentation: QueryRepresentable {
        public var queryOutput: SimpleDate

        public init(queryOutput: SimpleDate) {
            self.queryOutput = queryOutput
        }
    }
}

extension SimpleDate.ISODateRepresentation: QueryBindable {
    public var queryBinding: QueryBinding {
        let value = queryOutput.key
        return .text(value)
    }
}

extension SimpleDate.ISODateRepresentation: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws {
        let text: String = try String(decoder: &decoder)
        let parts = text.split(separator: "-").map { Int($0)! }
        self.init(
            queryOutput: SimpleDate(
                year: parts[0],
                month: parts[1],
                day: parts[2]
            )
        )
    }
}

extension SimpleDate.ISODateRepresentation: SQLiteType {
    public static var typeAffinity: SQLiteTypeAffinity {
        .text
    }
}

fileprivate extension SimpleDate.ISODateRepresentation {
    static func ymd(_ y: Int, _ m: Int, _ d: Int) -> Self {
        .init(queryOutput: SimpleDate(year: y, month: m, day: d))
    }
    static func range(_ y: Int, _ m: Int? = nil, _ d: Int? = nil) -> (start: Self, end: Self) {

        let start: SimpleDate
        let end: SimpleDate

        switch (m, d) {
        case (nil, _):
            // 年全体
            start = .init(year: y, month: 1, day: 1)
            end   = .init(year: y, month: 12, day: 31)

        case (let m?, nil):
            // 月全体
            start = .init(year: y, month: m, day: 1)
            end   = .init(year: y, month: m, day: 31)

        case (let m?, let d?):
            // 単日
            start = .init(year: y, month: m, day: d)
            end   = start
        }

        return (
            .init(queryOutput: start),
            .init(queryOutput: end)
        )
    }
}

public extension TableColumn where QueryValue == SimpleDate.ISODateRepresentation {

    func inYear(_ year: Int) -> some QueryExpression<Bool> {
        let range = SimpleDate.ISODateRepresentation.range(year)
        return between(range.start, and: range.end)
    }

    func inMonth(_ year: Int, _ month: Int) -> some QueryExpression<Bool> {
        let range = SimpleDate.ISODateRepresentation.range(year, month)
        return between(range.start, and: range.end)
    }

    func on(_ year: Int, _ month: Int, _ day: Int) -> some QueryExpression<Bool> {
        let range = SimpleDate.ISODateRepresentation.range(year, month, day)
        return between(range.start, and: range.end)
    }
}
