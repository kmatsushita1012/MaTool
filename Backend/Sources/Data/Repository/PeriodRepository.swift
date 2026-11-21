//
//  PeriodRepository.swift
//  matool-backend
//

import Dependencies
import Shared

// MARK: - DependencyKey

enum PeriodRepositoryKey: DependencyKey {
    static let liveValue: PeriodRepositoryProtocol = PeriodRepository()
}

// MARK: - Repository

protocol PeriodRepositoryProtocol: Sendable {
    func get(id: Period.ID) async throws -> Period?
    func query(byEditionId editionId: Edition.ID) async throws -> [Period]
    func query(by festivalId: Festival.ID, year: Int) async throws -> [Period]
    func query(by festivalId: Festival.ID) async throws -> [Period]
    func post(_ period: Period) async throws -> Period
    func put(_ period: Period) async throws -> Period
    func delete(id: Period.ID) async throws
}

struct PeriodRepository: PeriodRepositoryProtocol {
    private let dataStore: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var dataStoreFactory
        self.dataStore = dataStoreFactory(DynamoDBConfiguration.tableName)
    }

    func get(id: Period.ID) async throws -> Period? {
        let keys = PeriodRecord.makeKeys(id: id)
        let records = try await dataStore.query(
            indexName: keys.indexName,
            queryConditions: [keys.pk, keys.sk],
            as: PeriodRecord.self
        )
        return records.first?.content
    }

    func query(byEditionId editionId: Edition.ID) async throws -> [Period] {
        let keys = PeriodRecord.makeKeys(editionId: editionId)
        let records = try await dataStore.query(queryConditions: [keys.pk, keys.sk], as: PeriodRecord.self)
        return records.map(\.content).sorted()
    }

    func query(by festivalId: Festival.ID, year: Int) async throws -> [Period] {
        let editionKeys = EditionRecord.makeKeys(festivalId: festivalId, year: year)
        guard let edition = try await dataStore.get(pk: editionKeys.pk, sk: editionKeys.sk, as: EditionRecord.self) else {
            return []
        }
        return try await query(byEditionId: edition.content.id)
    }

    func query(by festivalId: Festival.ID) async throws -> [Period] {
        let keys = EditionRecord.makeKeys(festivalId: festivalId)
        let editions = try await dataStore.query(queryConditions: [keys.pk, keys.sk], as: EditionRecord.self)
        var periods: [Period] = []
        for edition in editions {
            periods += try await query(byEditionId: edition.content.id)
        }
        return periods.sorted()
    }

    func post(_ period: Period) async throws -> Period {
        try await dataStore.put(PeriodRecord(period))
        return period
    }

    func put(_ period: Period) async throws -> Period {
        let record = try PeriodRecord(period)
        let idKeys = PeriodRecord.makeKeys(id: period.id)
        let existingRecords = try await dataStore.query(
            indexName: idKeys.indexName,
            queryConditions: [idKeys.pk, idKeys.sk],
            as: PeriodRecord.self
        )

        for existingRecord in existingRecords
        where existingRecord.id == period.id
            && (existingRecord.pk != record.pk || existingRecord.sk != record.sk) {
            try await dataStore.delete(pk: existingRecord.pk, sk: existingRecord.sk)
        }

        try await dataStore.put(record)
        return period
    }

    func delete(id: Period.ID) async throws {
        let keys = PeriodRecord.makeKeys(id: id)
        let records = try await dataStore.query(
            indexName: keys.indexName,
            queryConditions: [keys.pk, keys.sk],
            as: PeriodRecord.self
        )
        for record in records where record.id == id {
            try await dataStore.delete(pk: record.pk, sk: record.sk)
        }
    }
}

struct PeriodRecord: RecordProtocol {
    typealias Content = Period

    let pk: String
    let sk: String
    let type: String
    let id: String
    let content: Period

    init(_ content: Period) throws {
        guard let editionId = content.editionId else {
            throw Error.badRequest("日程にEditionが設定されていません。")
        }
        let keys = Self.makeKeys(editionId: editionId, id: content.id)
        self.pk = keys.pk
        self.sk = keys.sk
        self.type = Self.type
        self.id = content.id
        self.content = content
    }

    static func makeKeys(editionId: Edition.ID, id: Period.ID) -> (pk: String, sk: String) {
        (pk: "\(pkPrefix)\(editionId)", sk: "\(skPrefix)\(id)")
    }

    static func makeKeys(editionId: Edition.ID) -> (pk: QueryCondition, sk: QueryCondition) {
        (
            pk: .equals("pk", "\(pkPrefix)\(editionId)"),
            sk: .beginsWith("sk", skPrefix)
        )
    }

    static func makeKeys(id: Period.ID) -> (indexName: String, pk: QueryCondition, sk: QueryCondition) {
        (
            indexName: indexName,
            pk: .equals("type", type),
            sk: .equals("id", id)
        )
    }

    static let pkPrefix = "EDITION#"
    static let skPrefix = "PERIOD#"
    static let type = String(describing: Period.self).uppercased()
    static let indexName = "index-type-id"
}
