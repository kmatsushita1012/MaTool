//
//  EditionRepository.swift
//  matool-backend
//

import Dependencies
import Shared

enum EditionRepositoryKey: DependencyKey {
    static let liveValue: EditionRepositoryProtocol = EditionRepository()
}

extension DependencyValues {
    var editionRepository: EditionRepositoryProtocol {
        get { self[EditionRepositoryKey.self] }
        set { self[EditionRepositoryKey.self] = newValue }
    }
}

protocol EditionRepositoryProtocol: Sendable {
    func get(id: Edition.ID) async throws -> Edition?
    func get(festivalId: Festival.ID, year: Int) async throws -> Edition?
    func query(by festivalId: Festival.ID) async throws -> [Edition]
    func post(_ edition: Edition) async throws -> Edition
}

struct EditionRepository: EditionRepositoryProtocol {
    private let store: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        self.store = storeFactory("matool")
    }

    func get(id: Edition.ID) async throws -> Edition? {
        let keys = EditionRecord.makeKeys(id: id)
        let records = try await store.query(
            indexName: keys.indexName,
            queryConditions: [keys.pk, keys.sk],
            as: EditionRecord.self
        )
        return records.first?.content
    }

    func get(festivalId: Festival.ID, year: Int) async throws -> Edition? {
        let keys = EditionRecord.makeKeys(festivalId: festivalId, year: year)
        return try await store.get(pk: keys.pk, sk: keys.sk, as: EditionRecord.self)?.content
    }

    func query(by festivalId: Festival.ID) async throws -> [Edition] {
        let keys = EditionRecord.makeKeys(festivalId: festivalId)
        let records = try await store.query(queryConditions: [keys.pk, keys.sk], as: EditionRecord.self)
        return records.map(\.content)
    }

    func post(_ edition: Edition) async throws -> Edition {
        try await store.put(EditionRecord(edition))
        return edition
    }
}

struct EditionRecord: RecordProtocol {
    typealias Content = Edition

    let pk: String
    let sk: String
    let type: String
    let id: String
    let content: Edition

    init(_ content: Edition) {
        let keys = Self.makeKeys(festivalId: content.festivalId, year: content.year)
        self.pk = keys.pk
        self.sk = keys.sk
        self.type = Self.type
        self.id = content.id
        self.content = content
    }

    static func makeKeys(festivalId: Festival.ID, year: Int) -> (pk: String, sk: String) {
        (pk: "\(pkPrefix)\(festivalId)", sk: "\(skPrefix)\(year)")
    }

    static func makeKeys(festivalId: Festival.ID) -> (pk: QueryCondition, sk: QueryCondition) {
        (
            pk: .equals("pk", "\(pkPrefix)\(festivalId)"),
            sk: .beginsWith("sk", skPrefix)
        )
    }

    static func makeKeys(id: Edition.ID) -> (indexName: String, pk: QueryCondition, sk: QueryCondition) {
        (
            indexName: indexName,
            pk: .equals("type", type),
            sk: .equals("id", id)
        )
    }

    static let pkPrefix = "FESTIVAL#"
    static let skPrefix = "EDITION#"
    static let type = String(describing: Edition.self).uppercased()
    static let indexName = "index-type-id"
}
