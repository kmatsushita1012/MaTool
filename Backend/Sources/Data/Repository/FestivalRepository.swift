//
//  FestivalRepository.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Dependencies
import Shared

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
    func get(id: String) async throws -> Festival?
    func scan() async throws -> [Festival]
    func put(_ item: Festival) async throws -> Festival
}

// MARK: - FestivalRepository
struct FestivalRepository: FestivalRepositoryProtocol {
    private let store: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        self.store = storeFactory("matool_regions")
    }

    func get(id: String) async throws -> Festival? {
        let record = try await store.get(key: id, keyName: "id", as: Record<Festival>.self)
        return record?.content
    }

    func scan() async throws -> [Festival] {
        let records = try await store.scan(Record<Festival>.self)
        return records.map{ $0.content }
    }

    func put(_ item: Festival) async throws -> Festival {
        let record = Record(item)
        try await store.put(record)
        return item
    }
}

