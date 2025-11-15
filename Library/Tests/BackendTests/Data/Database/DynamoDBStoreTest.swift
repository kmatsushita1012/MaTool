//
//  DynamoDBStoreTest.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/15.
//

import Foundation
import Testing
@testable import Backend
@preconcurrency import AWSDynamoDB

@Suite(.serialized)
struct DynamoDBStoreTest {
    
    private struct TestUser: Codable, Equatable {
        let id: String
        let name: String
    }

    private let tableName = "test_table"
    private let subject: DynamoDBStore
    
    init() throws {
        self.subject = try DynamoDBStore(region: "ap-northeast-1", tableName: tableName)
    }
    
    @Test("Put → Get が動く")
    func testPutAndGet() async throws {
        let id = UUID().uuidString
        let user = TestUser(id: id, name: "IntegrationUser")

        
        try await subject.put(user)
        defer { Task { try? await subject.delete(key: id, keyName: "id") } }
        let result = try await subject.get(
            key: id,
            keyName: "id",
            as: TestUser.self
        )
        
        
        #expect(result != nil)
        #expect(result?.name == "IntegrationUser")
    }
    
    @Test("Delete が動く")
    func testDelete() async throws {
        let id = UUID().uuidString
        let user = TestUser(id: id, name: "DeleteTarget")
        
        
        try await subject.put(user)
        try await subject.delete(key: id, keyName: "id")
        let result = try await subject.get(key: id, keyName: "id", as: TestUser.self)
        
        
        #expect(result == nil)
    }
    
    @Test("Scan が実行できる")
    func testScan() async throws {
        let users = try await subject.scan(TestUser.self)
        
        
        #expect(users.count >= 0)
    }
    
    @Test("Query が動く（PK = id）")
    func testQuery() async throws {
        let id = UUID().uuidString
        let user = TestUser(id: id, name: "QueryUser")
        
        
        try await subject.put(user)
        defer { Task { try? await subject.delete(key: id, keyName: "id") } }
        let results = try await subject.query(
            keyCondition: .equals("id", id),
            as: TestUser.self
        )
        
        
        #expect(results.count > 0)
        #expect(results.first?.name == "QueryUser")
    }
}
