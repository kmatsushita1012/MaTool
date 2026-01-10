//
//  DistrictRepository.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Dependencies
import Shared

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
        self.store = storeFactory("matool_districts")
    }

    func get(id: String) async throws -> District? {
        let record = try await store.get(key: id, keyName: "id", as: Record<District>.self)
        return record?.content
    }

    func query(by festivalId: String) async throws -> [District] {
        let records = try await store.query(
            indexName: "region_id-index",
            keyCondition: .equals("region_id", festivalId),
            as: Record<District>.self
        )
        return records.map{ $0.content }
    }

    func put(id: String, item: District) async throws -> District  {
        let record = Record(item)
        try await store.put(record)
        return item
    }

    func post(item: District) async throws -> District  {
        let record = Record(item)
        try await store.put(record)
        return item
    }
}
