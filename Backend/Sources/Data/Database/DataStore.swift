//
//  DataStore.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Dependencies
import Foundation

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
    func transactWrite(_ mutations: [DataStoreMutation]) async throws
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

struct DataStoreItemKey: Hashable, Sendable {
    let pk: String
    let sk: String
}

struct DataStoreMutation: Sendable {
    enum Operation: Sendable {
        case put(Data)
        case delete
    }

    let key: DataStoreItemKey
    let operation: Operation

    static func put<Record: RecordProtocol>(_ record: Record) throws -> Self {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return .init(
            key: .init(pk: record.pk, sk: record.sk),
            operation: .put(try encoder.encode(record))
        )
    }

    static func delete(pk: String, sk: String) -> Self {
        .init(key: .init(pk: pk, sk: sk), operation: .delete)
    }

    static func validate(_ mutations: [Self]) throws {
        guard mutations.count <= 100 else {
            throw Error.badRequest("一度に更新できるデータ数の上限を超えています。")
        }

        guard Set(mutations.map(\.key)).count == mutations.count else {
            throw Error.badRequest("一度に同じデータを複数回更新できません。")
        }
    }
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
            indexName: indexName,
            keyConditions: queryConditions,
            filterConditions: filterConditions,
            limit: limit,
            ascending: ascending,
            as: type
        )
    }
}
