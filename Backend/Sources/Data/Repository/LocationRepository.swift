//
//  LocationRepository.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Dependencies
import Shared

// MARK: - Dependencies
enum LocationRepositoryKey: DependencyKey {
    static let liveValue: any LocationRepositoryProtocol = LocationRepository()
}

extension DependencyValues {
    var locationRepository: LocationRepositoryProtocol {
        get { self[LocationRepositoryKey.self] }
        set { self[LocationRepositoryKey.self] = newValue }
    }
}

// MARK: - LocationRepositoryProtocol
protocol LocationRepositoryProtocol: Sendable {
    func get(id: String) async throws -> FloatLocation?
    func scan() async throws -> [FloatLocation]
    func put(_ location: FloatLocation) async throws -> FloatLocation
    func delete(districtId: String) async throws
}

// MARK: - LocationRepository
struct LocationRepository: LocationRepositoryProtocol {
    private let store: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        self.store = storeFactory("matool_locations")
    }

    func get(id: String) async throws -> FloatLocation? {
        let record = try await store.get(key: id, keyName: "district_id", as: Record<FloatLocation>.self)
        return record?.content
    }

    func scan() async throws -> [FloatLocation] {
        let records = try await store.scan(Record<FloatLocation>.self)
        return records.map{ $0.content }
    }

    func put(_ location: FloatLocation) async throws -> FloatLocation {
        let record = Record(location)
        try await store.put(record)
        return location
    }

    func delete(districtId: String) async throws {
        try await store.delete(key: districtId, keyName: "district_id")
    }
}
