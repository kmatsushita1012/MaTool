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
}

extension Legacy.Span {
    func toPeriod() -> Period {
        Period(id: id, title: "", date: .from(start), start: .from(start), end: .from(end))
    }
}
