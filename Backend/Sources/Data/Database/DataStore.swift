//
//  DataStore.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Dependencies

// MARK: - Dependencies
enum DataStoreFactoryKey: DependencyKey {
    static let liveValue: DataStoreFactory = { tableName in
        DynamoDBStore.make(tableName: tableName)
    }
}

extension DependencyValues {
    var dataStoreFactory: DataStoreFactory {
        get { self[DataStoreFactoryKey.self] }
        set { self[DataStoreFactoryKey.self] = newValue }
    }
}

typealias DataStoreFactory = @Sendable (String) -> DataStore

// MARK: - DataStore
protocol DataStore: Sendable {
    func put<T: Codable>(_ item: T) async throws
    func get<T: Codable>(keys: [String: Codable], as type: T.Type) async throws -> T?
    func delete(keys: [String: Codable]) async throws
    func scan<T: Codable>(_ type: T.Type) async throws -> [T]
    func query<T: Codable>(
        indexName: String?,
        keyConditions: [QueryCondition],
        filterConditions: [FilterCondition],
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
        filterCondition: FilterCondition? = nil,
        limit: Int? = nil,
        ascending: Bool = true,
        as type: T.Type
    ) async throws -> [T] {
        return try await query(
            indexName: indexName,
            keyConditions: [keyCondition],
            filterConditions: filterCondition != nil ? [filterCondition!] : [],
            limit: limit,
            ascending: ascending,
            as: type
        )
    }
    
    func query<T: Codable>(
        indexName: String? = nil,
        keyConditions: [QueryCondition],
        as type: T.Type
    ) async throws -> [T] {
        return try await query(
            indexName: indexName,
            keyConditions: keyConditions,
            filterConditions: [],
            limit: nil,
            ascending: true,
            as: type
        )
    }
    
    func get<T: Codable, K: Codable>(key: K, keyName: String, as type: T.Type) async throws -> T? {
        try await get(keys: [keyName: key], as: type)
    }
    
    func delete<K: Codable>(key: K, keyName: String) async throws {
        try await delete(keys: [keyName: key])
    }
}
