//
//  PeriodInjector.swift
//  matool-backend
//
//  Created by 松下和也 on 2026/01/10.
//

import Testing
@testable import Backend
import Shared
import Dependencies
import Foundation

struct PeriodInjector{
    @Test func inject_periods() async throws {
        let period = Period(id: UUID().uuidString, festivalId: "test_region", title: "夜", date: .init(year: 2026, month: 10, day: 12), start: .init(hour: 18, minute: 0), end: .init(hour: 21, minute: 0))
        let subject = withDependencies({
            $0[DataStoreFactoryKey.self] = { try! DynamoDBStore(tableName: $0) }
        }) {
            PeriodRepository()
        }
        _ = try await subject.post(period)
    }
}
