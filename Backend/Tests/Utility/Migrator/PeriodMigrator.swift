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

struct PeriodMigrator {
    @Test(.disabled()) func post() async throws {
        let item = Period(id: UUID().uuidString, festivalId: "test_region2", title: "夜", date: .init(year: 2026, month: 10, day: 10), start: .init(hour: 18, minute: 0), end: .init(hour: 21, minute: 0))
        let repository = PeriodRepository()
        _ = try await repository.post(item)
    }
}
