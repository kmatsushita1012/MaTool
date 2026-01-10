//
//  DistrictRepository.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Dependencies
import Shared

fileprivate typealias DRecord = Record<District>

// MARK: Dependencies
enum DistrictRepositoryKey: DependencyKey {
    static let liveValue: any DistrictRepositoryProtocol = DistrictRepository()
}

extension DependencyValues {
    var districtRepository: DistrictRepositoryProtocol {
        get { self[DistrictRepositoryKey.self] }
        set { self[DistrictRepositoryKey.self] = newValue }
    }
}

// MARK: - DistrictRepositoryProtocol
protocol DistrictRepositoryProtocol: Sendable {
    func get(id: String) async throws -> District?
    func query(by festivalId: String) async throws -> [District]
    func put(id: String, item: District) async throws -> District
    func post(item: District) async throws -> District
}

// MARK: - DistrictRepository
struct DistrictRepository: DistrictRepositoryProtocol {
    private let store: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        self.store = storeFactory("matool")
    }

    func get(id: String) async throws -> District? {
        let keys = DRecord.makeKeys(id)
        let records = try await store.query(indexName: keys.indexName, queryConditions: [keys.pk, keys.sk], as: DRecord.self)
        return records.first?.content
    }

    func query(by festivalId: String) async throws -> [District] {
        let keys = DRecord.makeKeys(festivalId: festivalId)
        let records = try await store.query(queryConditions: [keys.pk, keys.sk], as: DRecord.self)
        return records.map(\.content)
    }

    func put(id: String, item: District) async throws -> District  {
        let record = DRecord(item)
        try await store.put(record)
        return item
    }

    func post(item: District) async throws -> District  {
        let record = DRecord(item)
        try await store.put(record)
        return item
    }
}

extension Record where Content == District {
    init(_ item: District) {
        let keys = Self.makeKeys(item.id, festivalId: item.festivalId)
        self.init(pk: keys.pk,sk: keys.sk, type: Self.type, content: item)
    }
    
    static func makeKeys(_ id: String, festivalId: String) -> (pk: String, sk: String){
        (pk: "\(pkPrefix)\(festivalId)", sk:"\(skPrefix)\(id)")
    }
    
    static func makeKeys(festivalId: String) -> (pk: QueryCondition, sk: QueryCondition){
        (pk: .equals("pk", "\(pkPrefix)\(festivalId)"), sk: .beginsWith("sk", "\(skPrefix)"))
    }
    
    static func makeKeys(_ id: String) -> (indexName: String, pk: QueryCondition, sk: QueryCondition) {
        (indexName: "index-TYPE", pk: .equals("type", "\(type)"), sk: .equals("sk", "\(skPrefix)\(id)"))
    }
    
    static let pkPrefix = "FESTIVAL#"
    static let skPrefix = "DISTRICT#"
    static let type = String(describing: District.self).uppercased()
}
