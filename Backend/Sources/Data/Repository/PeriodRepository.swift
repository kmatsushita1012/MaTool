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
    static let liveValue: PeriodRepositoryProtocol = {
        @Dependency(\.dataStoreFactory) var dataStoreFactory
        return PeriodRepository()
    }()
}

// MARK: - Repository

protocol PeriodRepositoryProtocol: Sendable {
    func get(id: Period.ID) async throws -> Period?
    func query(by festivalId: String, year: Int) async throws -> [Period]
    func query(by festivalId: String) async throws -> [Period]
    func post(_ Period: Period) async throws -> Period
    func put(_ Period: Period) async throws -> Period
    func delete(festivalId: String, date: SimpleDate, start: SimpleTime) async throws
}

struct PeriodRepository: PeriodRepositoryProtocol {
    private let dataStore: DataStore

    init() {
        @Dependency(DataStoreFactoryKey.self) var dataStoreFactory
        self.dataStore = dataStoreFactory("matool")
    }
    
    func get(id: Period.ID) async throws -> Period? {
        let keys = PeriodRecord.makeKeys(id: id)
        let records = try await dataStore.query(indexName: keys.indexName, queryConditions: [keys.pk, keys.sk], as: PeriodRecord.self)
        return records.first?.content
    }

    func query(by festivalId: String, year: Int) async throws -> [Period] {
        let keys = PeriodRecord.makeKeys(festivalId: festivalId, year: year)
        let records = try await dataStore.query(queryConditions: [ keys.pk, keys.sk ], as: PeriodRecord.self)
        return records.map(\.content)
    }

    func query(by festivalId: String) async throws -> [Period] {
        let keys = PeriodRecord.makeKeys(festivalId: festivalId)
        let records =  try await dataStore.query(queryConditions: [keys.pk, keys.sk], as: PeriodRecord.self)
        return records.map(\.content)
    }

    func post(_ item: Period) async throws -> Period {
        let record = PeriodRecord(item)
        try await dataStore.put(record)
        return item
    }

    func put(_ item: Period) async throws -> Period {
        let record = PeriodRecord(item)
        try await dataStore.put(record)
        return item
    }

    func delete(festivalId: String, date: SimpleDate, start: SimpleTime) async throws {
        let keys = PeriodRecord.makeKeys(festivalId: festivalId, date: date, start: start)
        try await dataStore.delete(keys: ["pk": keys.pk, "sk": keys.sk])
    }
}

struct PeriodRecord: RecordProtocol {
    typealias Content = Period
    let pk: String
    let sk: String
    let type: String
    let id: String
    let content: Period
}

extension PeriodRecord {
    init(_ content: Period){
        let keys = Self.makeKeys(festivalId: content.festivalId, date: content.date, start: content.start)
        self.init(pk: keys.pk, sk: keys.sk, type: Self.type, id: content.id, content: content)
    }
    
    static func makeKeys(festivalId: String, date: SimpleDate, start: SimpleTime) -> (pk: String, sk: String){
        (pk: "\(pkPrefix)\(festivalId)", "\(skPrefix)\(date.sortableKey)#\(start.sortableKey)" )
    }
    
    static func makeKeys(festivalId: String, year: Int) -> (pk: QueryCondition, sk: QueryCondition){
        (pk: .equals("pk", "\(pkPrefix)\(festivalId)"), sk: .beginsWith("sk", "\(skPrefix)\(year)"))
    }
    
    static func makeKeys(festivalId: String) -> (pk: QueryCondition, sk: QueryCondition){
        (pk: .equals("pk", "\(pkPrefix)\(festivalId)"), sk: .beginsWith("sk", (skPrefix)))
    }
    
    static func makeKeys(id: String) -> (indexName: String, pk: QueryCondition, sk: QueryCondition){
        (indexName: indexName, pk: .equals("type",  type), sk: .equals("id", id))
    }
    
    static let pkPrefix = "FESTIVAL#"
    static let skPrefix = "PERIOD#"
    static let type = String(describing: Period.self).uppercased()
    static let indexName = "index-type-id"
}
