//
//  LocationRepository.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Dependencies
import Shared
import Foundation

typealias LRecord = Record<FloatLocation>

enum LocationRepositoryKey: DependencyKey {
    static let liveValue: any LocationRepositoryProtocol = LocationRepository()
}

protocol LocationRepositoryProtocol: Sendable {
    func get(festivalId: String, districtId: String) async throws -> FloatLocation?
    func query(by festivalId: String) async throws -> [FloatLocation]
    func post(_ location: FloatLocation, festivalId: Festival.ID) async throws -> FloatLocation
    func put(_ location: FloatLocation, festivalId: Festival.ID) async throws -> FloatLocation
    func delete(festivalId: String, districtId: String) async throws
}

struct LocationRepository: LocationRepositoryProtocol {
    private let store: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        self.store = storeFactory("matool")
    }

    func get(festivalId: String, districtId: String) async throws -> FloatLocation? {
        let keys = LRecord.makeKeysForQuery(festivalId: festivalId, districtId: districtId)
        let records = try await store.query(queryConditions: [ keys.pk, keys.sk ], as: LRecord.self)
        return records.first?.content
    }

    func query(by festivalId: String) async throws -> [FloatLocation] {
        let keys = LRecord.makeKeys(festivalId: festivalId)
        let records = try await store.query(queryConditions: [ keys.pk, keys.sk ], as: LRecord.self)
        return records.map { $0.content }
    }

    func post(_ item: FloatLocation, festivalId: Festival.ID) async throws -> FloatLocation {
        let record = LRecord(item, festivalId: festivalId)
        try await store.put(record)
        return item
    }

    func put(_ item: FloatLocation, festivalId: Festival.ID) async throws -> FloatLocation {
        let record = LRecord(item, festivalId: festivalId)
        try await store.put(record)
        return item
    }

    func delete(festivalId: String, districtId: String) async throws {
        let keys = LRecord.makeKeys(festivalId: festivalId, districtId: districtId)
        try await store.delete(pk: keys.pk, sk: keys.sk)
    }
}

extension LRecord {
    init(_ content: FloatLocation, festivalId: String) {
        let keys = Self.makeKeys(festivalId: festivalId, districtId: content.districtId)
        self.init(pk: keys.pk, sk: keys.sk, type: Self.type, content: content)
    }

    // For writing exact keys
    static func makeKeys(festivalId: String, districtId: String) -> (pk: String, sk: String) {
        (pk: "\(pkPrefix)\(festivalId)", sk: "\(skPrefix)\(districtPrefix)\(districtId)")
    }

    // For querying a single record by exact keys
    static func makeKeysForQuery(festivalId: String, districtId: String) -> (pk: QueryCondition, sk: QueryCondition) {
        (pk: .equals("pk", "\(pkPrefix)\(festivalId)"), sk: .equals("sk", "\(skPrefix)\(districtPrefix)\(districtId)"))
    }

    // For querying all locations under a festival
    static func makeKeys(festivalId: String) -> (pk: QueryCondition, sk: QueryCondition) {
        (pk: .equals("pk", "\(pkPrefix)\(festivalId)"), sk: .beginsWith("sk", "\(skPrefix)"))
    }

    static let pkPrefix: String = "FESTIVAL#"
    static let skPrefix: String = "LOCATION#"
    static let districtPrefix: String = "DISTRICT#"
    static let type = String(describing: FloatLocation.self).uppercased()
    static let typeIndexName = "index-TYPE"
}
