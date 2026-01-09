//
//  FestivalRepository.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Dependencies
import Shared

fileprivate typealias FRecord = Record<Festival>

// MARK: - Dependencies
enum FestivalRepositoryKey: DependencyKey {
    static let liveValue: any FestivalRepositoryProtocol = FestivalRepository()
}

extension DependencyValues {
    var festivalRepository: FestivalRepositoryProtocol {
        get { self[FestivalRepositoryKey.self] }
        set { self[FestivalRepositoryKey.self] = newValue }
    }
}

// MARK: - FestivalRepositoryProtocol
protocol FestivalRepositoryProtocol: Sendable {
    func get(id: Festival.ID) async throws -> Festival?
    func scan() async throws -> [Festival]
    func put(_ item: Festival) async throws -> Festival
}

// MARK: - FestivalRepository
struct FestivalRepository: FestivalRepositoryProtocol {
    private let store: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        self.store = storeFactory("matool")
    }

    func get(id: Festival.ID) async throws -> Festival? {
        let keys = FRecord.make(id)
        let record = try await store.get(pk: keys.pk, sk: keys.sk, as: FRecord.self)
        return record?.content
    }

    func scan() async throws -> [Festival] {
        let keys = FRecord.make()
        let records = try await store.query(indexName: keys.indexName, queryConditions: [ keys.pk, keys.sk ], as: FRecord.self)
        return records.map{ $0.content }
    }

    func put(_ item: Festival) async throws -> Festival {
        let record = FRecord(item)
        try await store.put(record)
        return item
    }
}

fileprivate extension Record where Content == Festival {
    init(_ item: Festival) {
        let keys = Self.make(item.id)
        self.init(pk: keys.pk, sk: keys.sk, content: item)
    }
    
    static func make(_ id: Festival.ID) -> (pk: String, sk: String) {
        return (pk: "\(pkPrefix)\(id)", sk: "\(skPrefix)")
    }
    
    static func make() -> (indexName: String, pk: QueryCondition, sk: QueryCondition) {
        return (indexName: indexName, pk: .equals("type", type), sk: .equals("sk", skPrefix))
    }
    
    static private let pkPrefix: String = "FESTIVAL#"
    static private let skPrefix: String = "METADATA"
    static private let type = String(describing: Festival.self).uppercased()
    static private let indexName = "index-\(type)"
}
