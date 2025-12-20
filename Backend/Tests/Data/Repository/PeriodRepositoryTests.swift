//
//  PeriodPepositoryTests.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/20.
//

import Testing
import Dependencies
@testable import Backend
import Shared
import Foundation

struct PeriodRepositoryTests {
    
    @Test
    func test_get_正常() async throws {
        let expected = periodFactory(id: "p1")
        let expectedRecord = PeriodRecord(expected)
        var lastCalledKeys: [String: Any] = [:]
        var lastCalledType: Any.Type?
        let store = DataStoreMock(
            getHandler: { keys, type in
                lastCalledKeys = keys
                lastCalledType = type
                return expectedRecord
            }
        )
        let repo = make(dataStore: store)

        
        let result: Period? = try await repo.get(id: "p1")

        
        #expect(store.getCallCount == 1)
        #expect(lastCalledKeys["id"] as! String == "p1")
        #expect(lastCalledType == PeriodRecord.self)
        #expect(result == expected)
    }

    @Test
    func test_get_存在しない() async throws {
        let store = DataStoreMock(getHandler: { _, _ in nil })
        let repo = make(dataStore: store)

        
        let result: Period? = try await repo.get(id: "missing")

        
        #expect(store.getCallCount == 1)
        #expect(result == nil)
    }

    @Test
    func test_query_正常() async throws {
        var lastCalled: QueryArgs? = nil
        let expected = [periodFactory(id: "p2")]
        let expectedRecords = [PeriodRecord(periodFactory(id: "p2"))]
        let store = DataStoreMock(queryHandler: { index, keyConds, filterConds, limit, asc, type in
            lastCalled = QueryArgs(indexName: index, keyConditions: keyConds, filterConditions: filterConds, limit: limit, ascending: asc, type: type)
            return expectedRecords
        })
        let repo = make(dataStore: store)

        
        let result: [Period] = try await repo.query(festivalId: "p2")

        
        #expect(store.queryCallCount == 1)
        let args = try #require(lastCalled)
        #expect(args.indexName == "festival_id_year")
        #expect(result == expected)
    }
    
    @Test
    func test_query_異常() async throws {
        let store = DataStoreMock(queryHandler: { _, _, _, _, _, _ in throw TestError.intentional })
        let repo = make(dataStore: store)
        
        
        await #expect(throws: TestError.intentional) {
            _ = try await repo.query(festivalId: "x") as [Period]
        }
    }

    @Test
    func test_query_byYear_正常() async throws {
        var lastCalled: QueryArgs? = nil
        let expected = [periodFactory(id: "p3")]
        let expectedRecords = [PeriodRecord(periodFactory(id: "p3"))]
        let store = DataStoreMock(queryHandler: { index, keyConds, filterConds, limit, asc, type in
            lastCalled = QueryArgs(indexName: index, keyConditions: keyConds, filterConditions: filterConds, limit: limit, ascending: asc, type: type)
            return expectedRecords
        })
        let repo = make(dataStore: store)

        
        let result: [Period] = try await repo.query(festivalId: "f-id", year: 2025)

        
        #expect(store.queryCallCount == 1)
        let args = try #require(lastCalled)
        #expect(args.indexName == "festival_id_year")
        #expect(result == expected)
    }
    
    @Test
    func test_query_byYear_異常() async throws {
        let store = DataStoreMock(queryHandler: { _, _, _, _, _, _ in throw TestError.intentional })
        let repo = make(dataStore: store)
        
        
        await #expect(throws: TestError.intentional) {
            _ = try await repo.query(festivalId: "f-id", year: 2025) as [Period]
        }
    }

    @Test
    func test_query_latest_正常() async throws {
        var lastCalled: QueryArgs? = nil
        let expected = [periodFactory(id: "p4")]
        let expectedRecords = [PeriodRecord(periodFactory(id: "p4"))]
        let store = DataStoreMock(queryHandler: { index, keyConds, filterConds, limit, asc, type in
            lastCalled = QueryArgs(indexName: index, keyConditions: keyConds, filterConditions: filterConds, limit: limit, ascending: asc, type: type)
            return expectedRecords
        })
        let repo = make(dataStore: store)
        
        
        let result: [Period] = try await repo.queryLatest(festivalId: "f-id")

        
        #expect(store.queryCallCount == 1)
        let args = try #require(lastCalled)
        #expect(args.indexName == "festival_id_year")
        #expect(result == expected)
    }
    
    @Test
    func test_query_latest_異常() async throws {
        let store = DataStoreMock(queryHandler: { _, _, _, _, _, _ in throw TestError.intentional })
        let repo = make(dataStore: store)
        
        
        await #expect(throws: TestError.intentional) {
            _ = try await repo.queryLatest(festivalId: "f-id") as [Period]
        }
    }

    @Test
    func test_put_正常() async throws {
        var lastCalledItem: PeriodRecord? = nil
        let store = DataStoreMock(putHandler: { item in
            lastCalledItem = item as? PeriodRecord
        })
        let repo = make(dataStore: store)
        let expected = periodFactory(id: "p3")
        let expectedRecord = PeriodRecord(expected)
        
        
        let result = try await repo.put(expected)

        
        #expect(store.putCallCount == 1)
        #expect(result == expected)
        #expect(lastCalledItem == expectedRecord)
    }

    @Test
    func test_put_異常() async throws {
        let store = DataStoreMock(putHandler: { _ in throw TestError.intentional })
        let repo = make(dataStore: store)
        
        
        await #expect(throws: TestError.intentional) {
            try await repo.put(periodFactory(id: "e1"))
        }
        #expect(store.putCallCount == 1)
    }

    @Test
    func test_delete_正常() async throws {
        var lastCalledKeys: [String: Any] = [:]
        let store = DataStoreMock(deleteHandler: { keys in
            lastCalledKeys = keys
        })
        let repo = make(dataStore: store)

        
        try await repo.delete(id: "p9")

        
        #expect(store.deleteCallCount == 1)
        #expect((lastCalledKeys["id"] as? String) == "p9")
    }
}

extension PeriodRepositoryTests {
    private func make(
        dataStore: DataStoreMock = .init()
    ) -> PeriodRepository {
        return withDependencies{
            $0[DataStoreFactoryKey.self] = { _ in dataStore }
        } operation: {
            PeriodRepository()
        }
    }
    
    private func periodFactory(id: String) -> Period{
        Period(id: id, festivalId: "f-id", date: .init(year: 2025, month: 10, day: 10), start: .init(hour: 9, minute: 0), end: .init(hour: 12, minute: 0))
    }
}

private struct QueryArgs: Equatable {
    var indexName: String?
    var keyConditions: [QueryCondition]
    var filterConditions: [FilterCondition]
    var limit: Int?
    var ascending: Bool
    var type: Any.Type

    static func == (lhs: QueryArgs, rhs: QueryArgs) -> Bool {
        return lhs.indexName == rhs.indexName &&
//        lhs.keyConditions == rhs.keyConditions &&
//        lhs.filterConditions == rhs.filterConditions &&
        lhs.limit == rhs.limit &&
        lhs.ascending == rhs.ascending &&
        String(reflecting: lhs.type) == String(reflecting: rhs.type)
    }
}
