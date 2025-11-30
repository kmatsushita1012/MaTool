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
        try await store.get(key: id, keyName: "id", as: Route.self)
    }

    func query(by districtId: String) async throws -> [Route] {
        try await store.query(
            indexName: "district_id-index",
            keyCondition: .equals("district_id", districtId),
            as: Route.self
        )
    }

    func post(_ route: Route) async throws -> Route {
        try await store.put(route)
        return route
    }

    func put(_ route: Route) async throws -> Route {
        try await store.put(route)
        return route
    }

    func delete(id: String) async throws {
        try await store.delete(key: id, keyName: "id")
        return
    }
}
