@testable import Backend
import Foundation

final class DataStoreMock<KeyType: Sendable & Codable, DataType: RecordProtocol>: DataStore {
    let response: DataType

    init(response: DataType) {
        self.response = response
    }

    nonisolated(unsafe) private(set) var putCallCount = 0
    nonisolated(unsafe) private(set) var putArg: DataType?
    func put<T: RecordProtocol>(_ item: T) async throws {
        putCallCount += 1
        putArg = try castOrThrow(item)
    }

    nonisolated(unsafe) private(set) var getCallCount = 0
    nonisolated(unsafe) private(set) var getArg: [String: Codable]?
    func get<T: RecordProtocol>(keys: [String : any Codable], as type: T.Type) async throws -> T? {
        getCallCount += 1
        getArg = keys
        return try castOrThrow(response)
    }

    nonisolated(unsafe) private(set) var deleteCallCount = 0
    nonisolated(unsafe) private(set) var deleteArg: [String: Codable]?
    func delete(keys: [String : any Codable]) async throws {
        deleteCallCount += 1
        deleteArg = keys
    }

    nonisolated(unsafe) private(set) var scanCallCount = 0
    nonisolated(unsafe) private(set) var scanArgIgnoreDecodeError: Bool?
    func scan<T: RecordProtocol>(_ type: T.Type, ignoreDecodeError: Bool) async throws -> [T] {
        scanCallCount += 1
        scanArgIgnoreDecodeError = ignoreDecodeError
        return [try castOrThrow(response)]
    }

    nonisolated(unsafe) private(set) var queryCallCount = 0
    nonisolated(unsafe) private(set) var queryArg: (
        String?,
        [QueryCondition],
        [FilterCondition],
        Int?,
        Bool
    )?
    func query<T: RecordProtocol>(
        indexName: String?,
        keyConditions: [QueryCondition],
        filterConditions: [FilterCondition],
        limit: Int?,
        ascending: Bool,
        as type: T.Type
    ) async throws -> [T] {
        queryCallCount += 1
        queryArg = (indexName, keyConditions, filterConditions, limit, ascending)
        return [try castOrThrow(response)]
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
