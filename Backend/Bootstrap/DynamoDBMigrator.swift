//
//  DynamoDBStore+Legacy.swift
//  matool-backend
//
//  Created by 松下和也 on 2026/02/20.
//

@testable import Backend
@preconcurrency import AWSDynamoDB

fileprivate typealias AttributeValue = DynamoDBClientTypes.AttributeValue

// MARK: - DynamoDBStore
struct DynamoDBMigrator {
    private let client: DynamoDBClient
    private let tableName: String
    private let encoder = DynamoDBEncoder()
    private let decoder = DynamoDBDecoder()
    
    init(region: String = "ap-northeast-1", tableName: String) throws {
        self.client = try DynamoDBClient(region: region)
        self.tableName = tableName
    }
    
    // MARK: put
    func put<R: RecordProtocol>(_ record: R) async throws {
        let attrs = try encoder.encode(record)
        let input = PutItemInput(item: attrs, tableName: tableName)
        let _ = try await client.putItem(input: input)
    }
    
    // MARK: scan
    func scan<T: Codable>(_ type: T.Type, ignoreDecodeError: Bool = true) async throws -> [T] {
        let input = ScanInput(tableName: tableName)
        let output = try await client.scan(input: input)
        guard let items = output.items else { return [] }
        if ignoreDecodeError {
            return items.compactMap { try? decoder.decode($0, as: T.self) }
        } else {
            return try items.map { try decoder.decode($0, as: T.self) }
        }
    }

    static func make(tableName: String) -> DynamoDBStore {
        guard let store = try? DynamoDBStore(tableName: tableName) else {
            fatalError("DynamoDBStore could not be initialized.")
        }
        return store
    }
}


