//
//  RouteRepositoryTest.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Testing
import Dependencies
import Shared
@testable import Backend

struct RouteRepositoryTest {
    let record: RouteRecord
    init() {
        let route = Route(
            id: "r-id",
            districtId: "d-id",
            periodId:"p-id"
        )
        record = .init(item: route, year: 2025)
    }
    
    @Test func test_get_routeId_正常() async throws {
        var lastKeys: [String : any Codable]? = nil
        var lastType: Any.Type? = nil
        let store = DataStoreMock(
            getHandler: { keys, type in
                lastKeys = keys
                lastType = type
                return self.record
            }
        )
        let subject = RouteRepository.make(store: store)

        
        let result = try await subject.get(id: "r-id")

        
        #expect(store.getCallCount == 1)
        let keys = try #require(lastKeys)
        #expect(keys.count == 1)
        let key = try #require(keys.first)
        #expect(key.key == "id")
        #expect(key.value as? String == "r-id")
        #expect(lastType == RouteRecord.self)
        #expect(result == self.record)
    }
    
    @Test func test_get_routeId_異常() async throws {
        let failingStore = DataStoreMock(
            getHandler: { _, _ in throw TestError.intentional }
        )
        let repo = RouteRepository.make(store: failingStore)

        
        await #expect(throws: TestError.intentional ) {
            _ = try await repo.get(id: "r-id")
        }
    }
    
    @Test func test_get_periodId_正常() async throws {
        var lastIndex: String? = nil
        var lastKeyConditions: [QueryCondition]? = nil
        var lastType: Any.Type? = nil
        let store = DataStoreMock(
            queryHandler: { index, keyConditions, _, _, _, type in
                lastIndex = index
                lastKeyConditions = keyConditions
                lastType = type
                return [self.record]
            }
        )
        let subject = RouteRepository.make(store: store)

        
        let result = try await subject.get(districtId: "d-id", periodId: "p-id")

        
        #expect(store.queryCallCount == 1)
        let keyConditions = try #require(lastKeyConditions)
        #expect(keyConditions.count == 2)
        guard case let .equals(firstKey, firstValue) = keyConditions.first else {
            Issue.record("Expected .equals(key, value) but got \(String(describing: keyConditions.first))")
            return
        }
        #expect(firstKey == "district_id")
        #expect(firstValue as? String == "d-id")
        guard case let .equals(secondKey, secondValue) = keyConditions[1] else {
            Issue.record("Expected .equals(key, value) but got \(String(describing: keyConditions[2]))")
            return
        }
        #expect(secondKey == "period_id")
        #expect(secondValue as? String == "p-id")
        #expect(lastType == RouteRecord.self)
        let rec = try #require(result)
        #expect(rec == self.record)
    }
    
    @Test func test_get_periodId_異常() async throws {
        let failingStore = DataStoreMock(
            queryHandler: { _, _, _, _, _, _  in throw TestError.intentional }
        )
        let repo = RouteRepository.make(store: failingStore)

        
        await #expect(throws: TestError.intentional ) {
            _ = try await repo.get(districtId: "d-id", periodId: "p-id")
        }
    }
    
    @Test func test_query_district_正常() async throws {
        var lastIndex: String? = nil
        var lastKeyConditions: [QueryCondition]? = nil
        let store = DataStoreMock(
            queryHandler: { index, keyConditions, _, _, _, _ in
                lastIndex = index
                lastKeyConditions = keyConditions
                return [self.record]
            }
        )
        let subject = RouteRepository.make(store: store)

        
        let result = try await subject.query(by: self.record.districtId)

        
        #expect(store.queryCallCount == 1)
        #expect(lastIndex == "district_id-index")
        let keyConditions = try #require(lastKeyConditions)
        #expect(keyConditions.count == 1)
        guard case let .equals(key, value) = keyConditions.first else {
            Issue.record("Expected .equals(key, value) but got \(String(describing: keyConditions.first))")
            return
        }
        #expect(key == "district_id")
        #expect(value as? String == "d-id")
        let item = try #require(result.first)
        #expect(item == self.record)
    }
    
    @Test func test_query_district_異常() async throws {
        let failingStore = DataStoreMock(
            queryHandler: { _, _, _, _, _, _ in throw TestError.intentional}
        )
        let repo = RouteRepository.make(store: failingStore)

        
        await #expect(throws: TestError.intentional) {
            _ = try await repo.query(by: "d-id")
        }
    }
    
    @Test func test_query_year_正常() async throws {
        var lastIndex: String? = nil
        var lastKeyConditions: [QueryCondition]? = nil
        let store = DataStoreMock(
            queryHandler: { index, keyConditions, _, _, _, _ in
                lastIndex = index
                lastKeyConditions = keyConditions
                return [self.record]
            }
        )
        let subject = RouteRepository.make(store: store)

        
        let result = try await subject.query(by: self.record.districtId, year: 2025)

        
        #expect(store.queryCallCount == 1)
        #expect(lastIndex == "district_id-year")
        let keyConditions = try #require(lastKeyConditions)
        #expect(keyConditions.count == 2)
        guard case let .equals(firstKey, firstValue) = keyConditions.first else {
            Issue.record("Expected .equals(key, value) but got \(String(describing: keyConditions.first))")
            return
        }
        #expect(firstKey == "district_id")
        #expect(firstValue as? String == "d-id")
        guard case let .equals(secondKey, secondValue) = keyConditions[1] else {
            Issue.record("Expected .equals(key, value) but got \(String(describing: keyConditions[2]))")
            return
        }
        #expect(secondKey == "year")
        #expect(secondValue as? Int == 2025)
        let item = try #require(result.first)
        #expect(item == self.record)
    }

    @Test func test_query_year_異常() async throws {
        let failingStore = DataStoreMock(
            queryHandler: { _, _, _, _, _, _ in throw TestError.intentional}
        )
        let repo = RouteRepository.make(store: failingStore)

        
        await #expect(throws: TestError.intentional) {
            _ = try await repo.query(by: "d-id", year: 2025)
        }
    }

    @Test func test_post_正常() async throws {
        var lastItem: RouteRecord? = nil
        let store = DataStoreMock(
            putHandler: { item in
                lastItem = item as? RouteRecord
                return ()
            }
        )
        let subject = RouteRepository.make(store: store)

        
        let result = try await subject.post(self.record)

        
        #expect(store.putCallCount == 1)
        #expect(lastItem == self.record)
        #expect(result == self.record)
    }
    
    @Test func test_post_異常() async throws {
        let failingStore = DataStoreMock(
            putHandler: { _ in throw TestError.intentional }
        )
        let repo = RouteRepository.make(store: failingStore)

        await #expect(throws: TestError.intentional) {
            try await repo.post(record)
        }
    }

    @Test func test_put_正常() async throws {
        var lastItem: RouteRecord? = nil
        let store = DataStoreMock(
            putHandler: { item in
                lastItem = item as? RouteRecord
                return ()
            }
        )
        let subject = RouteRepository.make(store: store)

        let result = try await subject.put(self.record)

        #expect(store.putCallCount == 1)
        #expect(lastItem == self.record)
        #expect(result == self.record)
    }
    
    @Test func test_put_異常() async throws {
        let failingStore = DataStoreMock(
            putHandler: { _ in throw TestError.intentional }
        )
        let repo = RouteRepository.make(store: failingStore)

        await #expect(throws: TestError.intentional) {
            try await repo.put(record)
        }
    }

    @Test func test_delete_正常() async throws {
        var lastKey: [String : any Codable]? = nil
        let store = DataStoreMock(
            deleteHandler: { key in
                lastKey = key
                return ()
            }
        )
        let subject = RouteRepository.make(store: store)
        
        
        try await subject.delete(id: record.id)
        
        
        #expect(store.deleteCallCount == 1)
        let key = try #require(lastKey)
        #expect(key["id"] as? String == self.record.id)
    }

    @Test func test_delete_異常() async throws {
        let failingStore = DataStoreMock(
            deleteHandler: { _ in throw TestError.intentional }
        )
        let repo = RouteRepository.make(store: failingStore)

        await #expect(throws: TestError.intentional) {
            try await repo.delete(id: "r-id")
        }
    }
}

private extension RouteRepository {
    static func make(store: DataStoreMock) -> RouteRepository {
        return withDependencies({
            $0.dataStoreFactory = { _ in store }
        }) {
            RouteRepository()
        }
    }
}

private enum SomeError: Swift.Error {
    case example
}

