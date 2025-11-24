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
        try await store.get(key: id, keyName: "id", as: Festival.self)
    }

    func scan() async throws -> [Festival] {
        try await store.scan(Festival.self)
    }

    func put(_ item: Festival) async throws -> Festival {
        try await store.put(item)
        return item
    }
}

