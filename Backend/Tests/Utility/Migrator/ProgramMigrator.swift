//
//  ProgramMigrator.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/07.
//

import Testing
@testable import Backend
import Shared
import Foundation

struct ProgramMigrator {
    @Test(.disabled()) func post() async throws {
        let item = Program(festivalId: "test_region", year: 2025, periods: [
            .init(id: UUID().uuidString, date: .init(year: 2025, month: 10, day: 12), start: .init(hour: 9, minute: 0), end: .init(hour: 12, minute: 0))
        ])
        let repository = ProgramRepository()
        _ = try await repository.post(item)
    }
}
