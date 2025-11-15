//
//  DataStore.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Dependencies

// MARK: - Dependencies
enum DataStreFactoryKey: DependencyKey {
    static let liveValue: DataStoreFactory = { tableName in
        DynamoDBStore.make(tableName: tableName)
    }
}

extension DependencyValues {
    var dataStoreFactory: DataStoreFactory {
        get { self[DataStreFactoryKey.self] }
        set { self[DataStreFactoryKey.self] = newValue }
    }
}

typealias DataStoreFactory = (String) -> DataStore

// MARK: - DataStore
protocol DataStore: Sendable {
    func put<T: Codable>(_ item: T) async throws
    func get<T: Codable, K: Codable>(key: K, keyName: String, as type: T.Type) async throws -> T?
    func delete<K: Codable>(key: K, keyName: String) async throws
    func scan<T: Codable>(_ type: T.Type) async throws -> [T]
    func query<T: Codable>(
        indexName: String?,
        keyCondition: QueryCondition,
        filter: FilterCondition?,
        limit: Int?,
        ascending: Bool,
        as type: T.Type
    ) async throws -> [T]
}

// MARK: - QueryCondition
enum QueryCondition: Sendable {
    case equals(_ field: String, _ value: Codable & Sendable)
    case beginsWith(_ field: String, _ prefix: String)
    case between(_ field: String, _ lower: Codable & Sendable, _ upper: Codable & Sendable)
}

// MARK: - FilterCondition
enum FilterCondition: Sendable {
    case equals(_ field: String, _ value: Codable & Sendable)
    case beginsWith(_ field: String, _ prefix: String)
    case contains(_ field: String, _ substring: String)
}

// MARK: - DataStore +
extension DataStore {
    func query<T: Codable>(
        indexName: String? = nil,
        keyCondition: QueryCondition,
        filter: FilterCondition? = nil,
        limit: Int? = nil,
        ascending: Bool = true,
        as type: T.Type
    ) async throws -> [T] {
        try await query(
            indexName: indexName,
            keyCondition: keyCondition,
            filter: filter,
            limit: limit,
            ascending: ascending,
            as: type
        )
    }
}
