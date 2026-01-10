//
//  RouteRepository.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Dependencies
import Shared

// MARK: - Dependencies
enum RouteRepositoryKey: DependencyKey {
    static let liveValue: any RouteRepositoryProtocol = RouteRepository()
}

extension DependencyValues {
    var routeRepository: RouteRepositoryProtocol {
        get { self[RouteRepositoryKey.self] }
        set { self[RouteRepositoryKey.self] = newValue }
    }
}

// MARK: - RouteRepositoryProtocol
protocol RouteRepositoryProtocol: Sendable {
    func get(id: String) async throws -> Route?
    func query(by districtId: String) async throws -> [Route]
    func post(_ route: Route) async throws -> Route
    func put(_ route: Route) async throws -> Route
    func delete(id: String) async throws
}

// MARK: - RouteRepository
struct RouteRepository: RouteRepositoryProtocol {
    private let store: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        self.store = storeFactory("matool_routes")
    }

    func get(id: String) async throws -> Route? {
        let record = try await store.get(key: id, keyName: "id", as: Record<Route>.self)
        return record?.content
    }

    func query(by districtId: String) async throws -> [Route] {
        let records = try await store.query(
            indexName: "district_id-index",
            keyCondition: .equals("district_id", districtId),
            as: Record<Route>.self
        )
        return records.map{ $0.content }
    }

    func post(_ item: Route) async throws -> Route {
        let record = Record(item)
        try await store.put(record)
        return item
    }

    func put(_ item: Route) async throws -> Route {
        let record = Record(item)
        try await store.put(record)
        return item
    }

    func delete(id: String) async throws {
        try await store.delete(key: id, keyName: "id")
        return
    }
}
