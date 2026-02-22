@testable import Backend
import Foundation

final class DataStoreMock: DataStore, @unchecked Sendable {
    init(
        putHandler: ((any Encodable) async throws -> Void)? = nil,
        getHandler: (([String: Codable], Any.Type) async throws -> Data?)? = nil,
        deleteHandler: (([String: Codable]) async throws -> Void)? = nil,
        scanHandler: ((Bool, Any.Type) async throws -> Data)? = nil,
        queryHandler: ((String?, [QueryCondition], [FilterCondition], Int?, Bool, Any.Type) async throws -> Data)? = nil
    ) {
        self.putHandler = putHandler
        self.getHandler = getHandler
        self.deleteHandler = deleteHandler
        self.scanHandler = scanHandler
        self.queryHandler = queryHandler
    }

    nonisolated(unsafe) private(set) var putCallCount = 0
    private let putHandler: ((any Encodable) async throws -> Void)?

    func put<T: RecordProtocol>(_ item: T) async throws {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        try await putHandler(item)
    }

    nonisolated(unsafe) private(set) var getCallCount = 0
    private let getHandler: (([String: Codable], Any.Type) async throws -> Data?)?

    func get<T: RecordProtocol>(keys: [String: Codable], as type: T.Type) async throws -> T? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        guard let data = try await getHandler(keys, type) else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    nonisolated(unsafe) private(set) var deleteCallCount = 0
    private let deleteHandler: (([String: Codable]) async throws -> Void)?

    func delete(keys: [String: Codable]) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try await deleteHandler(keys)
    }

    nonisolated(unsafe) private(set) var scanCallCount = 0
    private let scanHandler: ((Bool, Any.Type) async throws -> Data)?

    func scan<T: RecordProtocol>(_ type: T.Type, ignoreDecodeError: Bool) async throws -> [T] {
        scanCallCount += 1
        guard let scanHandler else { throw TestError.unimplemented }
        let data = try await scanHandler(ignoreDecodeError, type)
        return try JSONDecoder().decode([T].self, from: data)
    }

    nonisolated(unsafe) private(set) var queryCallCount = 0
    private let queryHandler: ((String?, [QueryCondition], [FilterCondition], Int?, Bool, Any.Type) async throws -> Data)?

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
        let data = try await queryHandler(indexName, keyConditions, filterConditions, limit, ascending, type)
        return try JSONDecoder().decode([T].self, from: data)
    }
}
