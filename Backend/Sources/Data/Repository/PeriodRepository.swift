//
//  PeriodRepository.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/05.
//

import Foundation
import Dependencies
import Shared

// MARK: - DependencyKey
enum PeriodRepositoryKey: DependencyKey {
    static let liveValue: PeriodRepositoryProtocol = PeriodRepository()
}

// MARK: - PeriodRepositoryProtocol
protocol PeriodRepositoryProtocol: Sendable {
    func get(id: String) async throws -> Period?
    func query(festivalId: String) async throws -> [Period]
    func query(festivalId: String, year: Int) async throws -> [Period]
    func post(_ period: Period) async throws -> Period
    func put(_ period: Period) async throws -> Period
    func delete(id: String) async throws
}

// MARK: - PeriodRepository
struct PeriodRepository: PeriodRepositoryProtocol {
    private let dataStore: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        self.dataStore = storeFactory("matool_periods")
    }

    func get(id: String) async throws -> Period? {
        guard let record = try await dataStore.get(keys: ["id": id], as: PeriodRecord.self) else {
            return nil
        }
        return record.item
    }

    func query(festivalId: String) async throws -> [Period] {
        let records = try await dataStore.query(
            indexName: "festival_id_year",
            keyCondition: .equals("festival_id", festivalId),
            ascending: false,
            as: PeriodRecord.self
        )
        return records.map{ $0.item }
    }

    func query(festivalId: String, year: Int) async throws -> [Period] {
        let records = try await dataStore.query(
            indexName: "festival_id_year",
            keyConditions: [.equals("festival_id", festivalId), .equals("year", year)],
            filterConditions: [],
            limit: nil,
            ascending: true,
            as: PeriodRecord.self
        )
        return records.map{ $0.item }
    }

    func post(_ period: Period) async throws -> Period {
        let record = PeriodRecord(period)
        try await dataStore.put(record)
        return period
    }

    func put(_ period: Period) async throws -> Period {
        let record = PeriodRecord(period)
        try await dataStore.put(record)
        return period
    }

    func delete(id: String) async throws {
        try await dataStore.delete(keys: ["id": id])
    }
}

extension PeriodRepositoryProtocol {
    func queryLatest(festivalId: String) async throws -> [Period] {
        return try await query(festivalId: festivalId)
    }
}
