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
    func get(id: String) async throws -> RouteRecord?
    func get(districtId: String, periodId: String) async throws -> RouteRecord?
    func query(by districtId: String) async throws -> [RouteRecord]
    func query(by districtId: String, year: Int) async throws -> [RouteRecord]
    func post(_ route: RouteRecord) async throws -> RouteRecord
    func put(_ route: RouteRecord) async throws -> RouteRecord
    func delete(id: String) async throws
}

// MARK: - RouteRepository
struct RouteRepository: RouteRepositoryProtocol {
    private let store: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        self.store = storeFactory("matool_routes")
    }

    func get(id: String) async throws -> RouteRecord? {
        try await store.get(key: id, keyName: "id", as: RouteRecord.self)
    }
    
    func get(districtId: String, periodId: String) async throws -> RouteRecord? {
        try await store.query(
            indexName: "district_id-period",
            keyConditions: [.equals("district_id", districtId), .equals("period_id", periodId)],
            as: RouteRecord.self
        ).first
    }

    func query(by districtId: String) async throws -> [RouteRecord] {
        try await store.query(
            indexName: "district_id-index",
            keyCondition: .equals("district_id", districtId),
            as: RouteRecord.self
        )
    }
    
    func query(by districtId: String, year: Int) async throws -> [RouteRecord] {
        try await store.query(
            indexName: "district_id-year",
            keyConditions: [.equals("district_id", districtId), .equals("year", year)],
            as: RouteRecord.self
        )
    }

    func post(_ route: RouteRecord) async throws -> RouteRecord {
        try await store.put(route)
        return route
    }

    func put(_ route: RouteRecord) async throws -> RouteRecord {
        try await store.put(route)
        return route
    }

    func delete(id: String) async throws {
        try await store.delete(key: id, keyName: "id")
        return
    }
}
