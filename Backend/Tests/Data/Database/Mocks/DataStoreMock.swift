@testable import Backend
import Foundation

final class DataStoreMock<KeyType: Sendable & Codable, DataType: RecordProtocol>: DataStore {
    init(
        putHandler: (@Sendable (DataType) async throws -> Void)? = nil,
        getHandler: (@Sendable ([String: Codable]) async throws -> DataType?)? = nil,
        deleteHandler: (@Sendable ([String: Codable]) async throws -> Void)? = nil,
        scanHandler: (@Sendable (Bool) async throws -> [DataType])? = nil,
        queryHandler: (@Sendable (String?, [QueryCondition], [FilterCondition], Int?, Bool) async throws -> [DataType])? = nil
    ) {
        self.putHandler = putHandler
        self.getHandler = getHandler
        self.deleteHandler = deleteHandler
        self.scanHandler = scanHandler
        self.queryHandler = queryHandler
    }

    nonisolated(unsafe) private(set) var putCallCount = 0
    private let putHandler: (@Sendable (DataType) async throws -> Void)?
    func put<T: RecordProtocol>(_ item: T) async throws {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        try await putHandler(try castOrThrow(item))
    }

    nonisolated(unsafe) private(set) var getCallCount = 0
    private let getHandler: (@Sendable ([String: Codable]) async throws -> DataType?)?
    func get<T: RecordProtocol>(keys: [String : any Codable], as type: T.Type) async throws -> T? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        guard let value = try await getHandler(keys) else { return nil }
        return try castOrThrow(value)
    }

    nonisolated(unsafe) private(set) var deleteCallCount = 0
    private let deleteHandler: (@Sendable ([String: Codable]) async throws -> Void)?
    func delete(keys: [String : any Codable]) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try await deleteHandler(keys)
    }

    nonisolated(unsafe) private(set) var scanCallCount = 0
    private let scanHandler: (@Sendable (Bool) async throws -> [DataType])?
    func scan<T: RecordProtocol>(_ type: T.Type, ignoreDecodeError: Bool) async throws -> [T] {
        scanCallCount += 1
        guard let scanHandler else { throw TestError.unimplemented }
        return try await scanHandler(ignoreDecodeError).map { try castOrThrow($0) }
    }

    nonisolated(unsafe) private(set) var queryCallCount = 0
    private let queryHandler: (@Sendable (String?, [QueryCondition], [FilterCondition], Int?, Bool) async throws -> [DataType])?
    func query<T: RecordProtocol>(
        indexName: String?,
        keyConditions: [QueryCondition],
        filterConditions: [FilterCondition],
        limit: Int?,
        ascending: Bool,
        as type: T.Type
    ) async throws -> [T] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(indexName, keyConditions, filterConditions, limit, ascending).map { try castOrThrow($0) }
    }
}

private extension DataStoreMock {
    func castOrThrow<T>(_ item: T) throws -> DataType {
        if let value = item as? DataType {
            return value
        }
        throw DataStoreMockError.typeMismatch(expected: DataType.self, actual: T.self)
    }

    func castOrThrow<T>(_ item: DataType) throws -> T {
        if let value = item as? T {
            return value
        }
        throw DataStoreMockError.typeMismatch(expected: T.self, actual: DataType.self)
    }
}

enum DataStoreMockError<E, A>: LocalizedError {
    case typeMismatch(expected: E.Type, actual: A.Type)

    var errorDescription: String? {
        switch self {
        case .typeMismatch(let expected, let actual):
            return "Type mismatch: expected \(expected), but got \(actual)."
        }
    }
}
