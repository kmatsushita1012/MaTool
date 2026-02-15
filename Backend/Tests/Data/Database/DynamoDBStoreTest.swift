////
////  DynamoDBStoreTest.swift
////  MaTool
////
////  Created by 松下和也 on 2025/11/15.
////
//
//import Foundation
//import Testing
//@testable import Backend
//@preconcurrency import AWSDynamoDB
//
//@Suite(.serialized)
//struct DynamoDBStoreTest {
//    
//    private struct Item: Codable, Equatable {
//        let id: String
//        let name: String
//        let int: Int
//        let date: Date
//        let double: Double
//        let bool: Bool
//        let array: [String]
//        let nested: Item.Child
//        let nestedArray: [Item.Child]
//        
//        struct Child: Codable, Equatable {
//            let id: String
//        }
//        
//        static func make(id: String, name: String) -> Self {
//            .init(id: id, name: name, int: 100, date: Date.now, double: 1.1, bool: true, array: ["array"], nested: .init(id: id), nestedArray: [.init(id: id)])
//        }
//    }
//
//    private let tableName = "test_table"
//    private let subject: DynamoDBStore
//    
//    init() throws {
//        self.subject = try DynamoDBStore(region: "ap-northeast-1", tableName: tableName)
//    }
//    
//    @Test("Put → Get が動く")
//    func testPutAndGet() async throws {
//        let id = UUID().uuidString
//        let item: Item = .make(id: id, name: "Put&Get")
//
//        
//        try await subject.put(item)
//        defer { Task { try? await subject.delete(key: id, keyName: "id") } }
//        let result = try await subject.get(
//            key: id,
//            keyName: "id",
//            as: Item.self
//        )
//        
//        
//        #expect(result != nil)
//        #expect(result?.id == id)
//        #expect(result?.name == "Put&Get")
//    }
//    
//    @Test("Delete が動く")
//    func testDelete() async throws {
//        let id = UUID().uuidString
//        let item: Item = .make(id: id, name: "Delete")
//        
//        
//        try await subject.put(item)
//        try await subject.delete(key: id, keyName: "id")
//        let result = try await subject.get(key: id, keyName: "id", as: Item.self)
//        
//        
//        #expect(result == nil)
//    }
//    
//    @Test("Scan が実行できる")
//    func testScan() async throws {
//        let users = try await subject.scan(Item.self)
//        
//        
//        #expect(users.count >= 0)
//    }
//    
//    @Test("Query が動く（PK = id）")
//    func testQuery() async throws {
//        let id = UUID().uuidString
//        let user: Item = .make(id: id, name: "Query")
//        
//        
//        try await subject.put(user)
//        defer { Task { try? await subject.delete(key: id, keyName: "id") } }
//        let results = try await subject.query(
//            keyCondition: .equals("id", id),
//            as: Item.self
//        )
//        
//        
//        #expect(results.count > 0)
//        #expect(results.first?.id == id)
//        #expect(results.first?.name == "Query")
//    }
//}
