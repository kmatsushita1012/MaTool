//
//  ActiveEditionRepository.swift
//  matool-backend
//

import Dependencies
import Shared

enum ActiveEditionRepositoryKey: DependencyKey {
    static let liveValue: ActiveEditionRepositoryProtocol = ActiveEditionRepository()
}

extension DependencyValues {
    var activeEditionRepository: ActiveEditionRepositoryProtocol {
        get { self[ActiveEditionRepositoryKey.self] }
        set { self[ActiveEditionRepositoryKey.self] = newValue }
    }
}

protocol ActiveEditionRepositoryProtocol: Sendable {
    func get(festivalId: Festival.ID) async throws -> ActiveEdition?
    func put(_ activeEdition: ActiveEdition) async throws -> ActiveEdition
}

struct ActiveEditionRepository: ActiveEditionRepositoryProtocol {
    private let store: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        self.store = storeFactory()
    }

    func get(festivalId: Festival.ID) async throws -> ActiveEdition? {
        let keys = ActiveEditionRecord.makeKeys(festivalId: festivalId)
        return try await store.get(pk: keys.pk, sk: keys.sk, as: ActiveEditionRecord.self)?.content
    }

    func put(_ activeEdition: ActiveEdition) async throws -> ActiveEdition {
        try await store.put(ActiveEditionRecord(activeEdition))
        return activeEdition
    }
}

struct ActiveEditionRecord: RecordProtocol {
    typealias Content = ActiveEdition

    let pk: String
    let sk: String
    let type: String
    let content: ActiveEdition

    init(_ content: ActiveEdition) {
        let keys = Self.makeKeys(festivalId: content.festivalId)
        self.pk = keys.pk
        self.sk = keys.sk
        self.type = Self.type
        self.content = content
    }

    static func makeKeys(festivalId: Festival.ID) -> (pk: String, sk: String) {
        (pk: "\(pkPrefix)\(festivalId)", sk: sk)
    }

    static let pkPrefix = "FESTIVAL#"
    static let sk = "ACTIVE_EDITION"
    static let type = String(describing: ActiveEdition.self).uppercased()
}
