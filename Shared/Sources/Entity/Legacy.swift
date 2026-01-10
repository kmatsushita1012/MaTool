//
//  Legacy.swift
//  matool-shared
//
//  Created by 松下和也 on 2025/12/04.
//

import Foundation

enum Legacy {
    // MARK: - Span
    struct Span: Entity {
        public let id: String
        public let start: Date
        public let end: Date
        
        public init(id: String, start: Date, end: Date) {
            self.id = id
            self.start = start
            self.end = end
        }
    }
    
    public struct Point: Entity {
        public let id: String
        public var coordinate: Coordinate
        @NullEncodable public var title: String?
        @NullEncodable public var description: String?
        @NullEncodable public var time: SimpleTime?
        public var isPassed: Bool
        public var shouldExport: Bool
        
        public init(
            id: String,
            coordinate: Coordinate,
            title: String? = nil,
            description: String? = nil,
            time: SimpleTime? = nil,
            isPassed: Bool = false,
            shouldExport: Bool = false
        ) {
            self.id = id
            self.coordinate = coordinate
            self.title = title
            self.description = description
            self.time = time
            self.isPassed = isPassed
            self.shouldExport = shouldExport
        }
    }
}

extension Legacy.Span {
    func toPeriod(festivalId: String) -> Period {
        Period(id: id, festivalId: festivalId, title: "", date: .from(start), start: .from(start), end: .from(end))
    }
}
