//
//  DataStoreMock.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

@testable import Backend
import Foundation

final class DataStoreMock: DataStore, @unchecked Sendable {

    // MARK: - Handlers（constructor injection）
    let putHandler: ((Any) async throws -> Void)?
    let getHandler: (([String: Codable], Any.Type) async throws -> Any?)?
    let deleteHandler: (([String: Codable]) async throws -> Void)?
    let scanHandler: ((Any.Type) async throws -> Any)?
    let queryHandler: ((
        String?,
        [QueryCondition],
        [FilterCondition],
        Int?,
        Bool,
        Any.Type
    ) async throws -> Any)?

    // MARK: - Call counts
    private(set) var putCallCount = 0
    private(set) var getCallCount = 0
    private(set) var deleteCallCount = 0
    private(set) var scanCallCount = 0
    private(set) var queryCallCount = 0

    // MARK: - Init
    init(
        putHandler: ((Any) async throws -> Void)? = nil,
        getHandler: (([String: Codable], Any.Type) async throws -> Any?)? = nil,
        deleteHandler: (([String: Codable]) async throws -> Void)? = nil,
        scanHandler: ((Any.Type) async throws -> Any)? = nil,
        queryHandler: ((
            String?,
            [QueryCondition],
            [FilterCondition],
            Int?,
            Bool,
            Any.Type
        ) async throws -> Any)? = nil
    ) {
        self.putHandler = putHandler
        self.getHandler = getHandler
        self.deleteHandler = deleteHandler
        self.scanHandler = scanHandler
        self.queryHandler = queryHandler
    }

    // MARK: - put
    func put<T: Codable>(_ item: T) async throws {
        putCallCount += 1
        guard let handler = putHandler else {
            throw TestError.unimplemented
        }
        try await handler(item)
    }

    // MARK: - get
    func get<T: Codable>(
        keys: [String: Codable],
        as type: T.Type
    ) async throws -> T? {
        getCallCount += 1
        guard let handler = getHandler else {
            throw TestError.unimplemented
        }

        let result = try await handler(keys, type)
        guard let result else { return nil }

        guard let typed = result as? T else {
            throw TestError.typeUnmatched(
                expected: T.self,
                actual: Swift.type(of: result)
            )
        }
        return typed
    }

    // MARK: - delete
    func delete(keys: [String: Codable]) async throws {
        deleteCallCount += 1
        guard let handler = deleteHandler else {
            throw TestError.unimplemented
        }
        try await handler(keys)
    }

    // MARK: - scan
    func scan<T: Codable>(_ type: T.Type) async throws -> [T] {
        scanCallCount += 1
        guard let handler = scanHandler else {
            throw TestError.unimplemented
        }

        let result = try await handler(type)

        guard let typed = result as? [T] else {
            throw TestError.typeUnmatched(
                expected: [T].self,
                actual: Swift.type(of: result)
            )
        }
        return typed
    }

    // MARK: - query
    func query<T: Codable>(
        indexName: String?,
        keyConditions: [QueryCondition],
        filterConditions: [FilterCondition],
        limit: Int?,
        ascending: Bool,
        as type: T.Type
    ) async throws -> [T] {

        queryCallCount += 1
        guard let handler = queryHandler else {
            throw TestError.unimplemented
        }

        let result = try await handler(
            indexName,
            keyConditions,
            filterConditions,
            limit,
            ascending,
            type
        )

        guard let typed = result as? [T] else {
            throw TestError.typeUnmatched(
                expected: [T].self,
                actual: Swift.type(of: result)
            )
        }
        return typed
    }
}
