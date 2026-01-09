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
    func put<T: RecordProtocol>(_ item: T) async throws
    func get<T: RecordProtocol>(keys: [String: Codable], as type: T.Type) async throws -> T?
    func delete(keys: [String: Codable]) async throws
    func scan<T: RecordProtocol>(_ type: T.Type, ignoreDecodeError: Bool) async throws -> [T]
    func query<T: RecordProtocol>(
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
    func query<T: RecordProtocol>(
        indexName: String? = nil,
        keyCondition: QueryCondition,
        filter: FilterCondition? = nil,
        limit: Int? = nil,
        ascending: Bool = true,
        as type: T.Type
    ) async throws -> [T] {
        try await query(
            indexName: indexName,
            keyConditions: [keyCondition],
            filterConditions: filter != nil ? [filter!] : [],
            limit: limit,
            ascending: ascending,
            as: type
        )
    }
    
    func get<T: RecordProtocol, K: Codable>(key: K, keyName: String, as type: T.Type) async throws -> T? {
        try await get(keys: [keyName: key], as: type)
    }
    
    func delete<K: Codable>(key: K, keyName: String) async throws {
        try await delete(keys: [keyName: key])
    }
    
    func scan<T: RecordProtocol>(_ type: T.Type) async throws -> [T] {
        try await scan(type, ignoreDecodeError: false)
    }
}

extension DataStore {
    func get<T: RecordProtocol>(pk: String, sk: String, as type: T.Type) async throws -> T? {
        let keys = [ "pk": pk, "sk": sk ]
        return try await get(keys: keys, as: type)
    }
    
    func delete(pk: String, sk: String) async throws {
        let keys = [ "pk": pk, "sk": sk ]
        try await delete(keys: keys)
    }
    
    func query<T: RecordProtocol>(
        indexName: String? = nil,
        queryConditions: [QueryCondition],
        filterConditions: [FilterCondition] = [],
        limit: Int? = nil,
        ascending: Bool = true,
        as type: T.Type
    ) async throws -> [T] {
        try await query(
            indexName: nil,
            keyConditions: queryConditions,
            filterConditions: filterConditions,
            limit: limit,
            ascending: ascending,
            as: type
        )
    }
}
