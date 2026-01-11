//
//  CheckpointRepository.swift
//  matool-backend
//
//  Created by 松下和也 on 2026/01/09.
//

import Dependencies
import Shared

fileprivate typealias CRecord = Record<Checkpoint>

// MARK: - Dependencies
enum CheckpointRepositoryKey: DependencyKey {
    static let liveValue: any CheckpointRepositoryProtocol = CheckpointRepository()
}

extension DependencyValues {
    var checkpointRepository: any CheckpointRepositoryProtocol {
        get { self[CheckpointRepositoryKey.self] }
        set { self[CheckpointRepositoryKey.self] = newValue }
    }
}

// MARK: - Protocol
protocol CheckpointRepositoryProtocol: Repository where Content == Checkpoint {
    func get(id: String) async throws -> Checkpoint?
    func query(by festivalId: Festival.ID) async throws -> [Checkpoint]
    func put(_ item: Checkpoint) async throws -> Checkpoint
    func post(_ item: Checkpoint) async throws -> Checkpoint
    func delete(_ item: Checkpoint) async throws
}

// MARK: - Repository
struct CheckpointRepository: CheckpointRepositoryProtocol {
    private let store: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        self.store = storeFactory("matool")
    }

    func get(id: String) async throws -> Checkpoint? {
        let keys = CRecord.make(id)
        let records = try await store.query(
            indexName: keys.indexName,
            queryConditions: [keys.pk, keys.sk],
            as: CRecord.self
        )
        return records.first?.content
    }
    
    func query(by festivalId: Festival.ID) async throws -> [Checkpoint] {
        let keys = CRecord.make(festivalId: festivalId)
        let records = try await store.query(queryConditions: [keys.pk, keys.sk], as: CRecord.self)
        return records.map { $0.content }
    }

    func put(_ item: Checkpoint) async throws -> Checkpoint {
        let record = CRecord(item)
        try await store.put(record)
        return item
    }

    func post(_ item: Checkpoint) async throws -> Checkpoint {
        let record = CRecord(item)
        try await store.put(record)
        return item
    }

    func delete(_ item: Checkpoint) async throws {
        let keys = CRecord.make(item.id, festivalId: item.festivalId)
        try await store.delete(pk: keys.pk, sk: keys.sk)
    }
}

fileprivate extension Record where Content == Checkpoint {
    init(_ item: Checkpoint) {
        let keys = Self.make(item.id, festivalId: item.festivalId)
        self.init(pk: keys.pk, sk: keys.sk, type: Self.type, content: item)
    }
    
    static func make(_ id: String, festivalId: String) -> (pk: String, sk: String) {
        return (pk: "\(pkPrefix)\(festivalId)", sk: "\(skPrefix)\(id)")
    }

    static func make(_ id: String) -> (indexName: String, pk: QueryCondition, sk: QueryCondition) {
        return (indexName: indexName, pk: .equals("type", "\(type)"), sk: .equals("sk", "\(skPrefix)\(id)"))
    }
    
    static func make(festivalId: String) -> (pk: QueryCondition, sk: QueryCondition) {
        return (pk: .equals("pk", "\(pkPrefix)\(festivalId)"), sk: .beginsWith("sk",  skPrefix))
    }

    static private let pkPrefix: String = "FESTIVAL#"
    static private let skPrefix: String = "CHECKPOINT#"
    static private let type = String(describing: Checkpoint.self).uppercased()
    static private let indexName: String = "index-TYPE"
}

