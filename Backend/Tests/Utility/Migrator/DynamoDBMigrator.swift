//
//  DynamoDBMigrator.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/01.
//


import Foundation
import Testing
import Shared
@testable import Backend

// 既存の DynamoDBStore を使用するため、import のみ
@preconcurrency import AWSDynamoDB

// MARK: - DynamoDBMigrator

struct DynamoDBMigrator {

    private let store: DynamoDBStore

    init(store: DynamoDBStore) {
        self.store = store
    }

    /// 全件 scan 移行
    func migrateAll<Old: Codable, New: Codable>(
        oldType: Old.Type,
        newType: New.Type,
        transform: @escaping (Old) throws -> New
    ) async throws {
        let items = try await store.scan(oldType)
        for oldItem in items {
            let newItem = try transform(oldItem)
            try await store.put(newItem)
        }
    }

    /// Query 条件で部分移行
    func migrateWhere<Old: Codable, New: Codable>(
        oldType: Old.Type,
        newType: New.Type,
        indexName: String? = nil,
        queryCondition: QueryCondition,
        filter: FilterCondition? = nil,
        transform: @escaping (Old) throws -> New
    ) async throws {
        let items = try await store.query(
            indexName: indexName,
            keyCondition: queryCondition,
            filter: filter,
            as: oldType
        )
        for oldItem in items {
            let newItem = try transform(oldItem)
            try await store.put(newItem)
        }
    }
}
