////
////  DataStoreMock.swift
////  MaTool
////
////  Created by 松下和也 on 2025/11/14.
////
//
//@testable import Backend
//import Foundation
//
//final class DataStoreMock<KeyType: Sendable & Codable ,DataType: Sendable & Codable>: DataStore {
//    let response: DataType
//    
//    init(response: DataType) {
//        self.response = response
//    }
//    
//    nonisolated(unsafe) private(set) var putCallCount: Int = 0
//    nonisolated(unsafe) private(set) var putArg: DataType? = nil
//    func put<T>(_ item: T) async throws {
//        putCallCount += 1
//        putArg = try castOrThrow(item)
//    }
//    
//    nonisolated(unsafe) private(set) var getCallCount: Int = 0
//    nonisolated(unsafe) private(set) var getArg: (KeyType, String, DataType.Type)? = nil
//    func get<T, K>(key: K, keyName: String, as type: T.Type) async throws -> T? {
//        getCallCount += 1
//        getArg = (try castOrThrow(key), keyName, try castOrThrow(type))
//        return try castOrThrow(response)
//    }
//    
//    // TODO: 正規化
//    func get<T>(keys: [String : any Codable], as type: T.Type) async throws -> T? where T : Decodable, T : Encodable {
//        getCallCount += 1
//        return try castOrThrow(response)
//    }
//    
//    nonisolated(unsafe) private(set) var deleteCallCount: Int = 0
//    nonisolated(unsafe) private(set) var deleteArg: (KeyType, String)? = nil
//    func delete<K>(key: K, keyName: String) async throws  {
//        deleteCallCount += 1
//        deleteArg = (try castOrThrow(key), keyName)
//    }
//    
//    // TODO: 正規化
//    func delete(keys: [String : any Codable]) async throws {
//        deleteCallCount += 1
//    }
//    
//    nonisolated(unsafe) private(set) var scanCallCount: Int = 0
//    nonisolated(unsafe) private(set) var scanArg: DataType.Type? = nil
//    func scan<T>(_ type: T.Type) async throws -> [T] where T : Decodable, T : Encodable {
//        scanCallCount += 1
//        scanArg = try castOrThrow(type)
//        return [try castOrThrow(response)]
//    }
//    
//    nonisolated(unsafe) private(set) var queryCallCount: Int = 0
//    nonisolated(unsafe) private(set) var queryArg: (
//        String?,
//        QueryCondition,
//        FilterCondition?,
//        Int?,
//        Bool,
//        DataType.Type
//    )? = nil
//    func query<T>(indexName: String?, keyCondition: QueryCondition, filter: FilterCondition?, limit: Int?, ascending: Bool, as type: T.Type) async throws -> [T]  {
//        queryCallCount += 1
//        queryArg = (
//            indexName,
//            keyCondition,
//            filter,
//            limit,
//            ascending,
//            try castOrThrow(type)
//        )
//        return [try castOrThrow(response)]
//    }
//}
//
//private extension DataStoreMock {
//    func castOrThrow<T>(_ item: T) throws -> KeyType {
//        if let value = item as? KeyType {
//            return value
//        } else {
//            throw DataStoreMockError.typeMismatch(
//                expected: KeyType.self,
//                actual: T.self
//            )
//        }
//    }
//    
//    func castOrThrow<T>(_ item: T.Type) throws -> DataType.Type {
//        if let value = item as? DataType.Type {
//            return value
//        } else {
//            throw DataStoreMockError.typeMismatch(
//                expected: DataType.Type.self,
//                actual: T.Type.self
//            )
//        }
//    }
//
//    func castOrThrow<T>(_ item: T) throws -> DataType {
//        if let value = item as? DataType {
//            return value
//        } else {
//            throw DataStoreMockError.typeMismatch(
//                expected: DataType.self,
//                actual: T.self
//            )
//        }
//    }
//    
//    func castOrThrow<T>(_ item: DataType) throws -> T {
//        if let value = item as? T {
//            return value
//        } else {
//            throw DataStoreMockError.typeMismatch(
//                expected: T.self,
//                actual: DataType.self
//            )
//        }
//    }
//}
//
//enum DataStoreMockError<E, A>: LocalizedError {
//    case notFound
//    case typeMismatch(expected: E.Type, actual: A.Type)
//    
//    var errorDescription: String? {
//        switch self {
//        case .notFound:
//            return "Requested item was not found in the mock."
//        case .typeMismatch(let expected, let actual):
//            return "Type mismatch: expected \(expected), but got \(actual)."
//        }
//    }
//}
