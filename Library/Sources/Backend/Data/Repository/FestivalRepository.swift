//
//  FestivalRepository.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//
import Shared

final class DynamoDBDistrictRepository: DistrictRepository {
    private let store: DataStore

    init(store: DataStore) {
        self.store = store
    }

    func get(id: String) async throws -> District? {
        try await store.get(key: id, keyName: "id", as: District.self)
    }

    func queryBy(festivalId: String) async throws -> [District] {
        try await store.query(
            indexName: "region_id-index",
            keyCondition: .equals("region_id", festivalId),
            as: District.self
        )
    }

    func put(id: String, item: District) async throws {
        // そのまま渡す
        try await store.put(item)
    }

    func post(item: District) async throws {
        try await store.put(item)
    }
}
