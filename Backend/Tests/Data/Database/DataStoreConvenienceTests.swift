import Dependencies
import Shared
import Testing
@testable import Backend

struct DataStoreConvenienceTests {
    @Test("PKとSKを指定した取得は正しいキーでRecordを読み込む")
    func getByPartitionAndSortKeys() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        var received: [String: Codable] = [:]
        let store = DataStoreMock(getHandler: { keys, _ in
            received = keys
            return try encodeForDataStore(Record(district))
        })

        let result: Record<District>? = try await store.get(
            pk: "FESTIVAL#festival-1",
            sk: "DISTRICT#district-1",
            as: Record<District>.self
        )

        #expect(result?.content == district)
        #expect(received["pk"] as? String == "FESTIVAL#festival-1")
        #expect(received["sk"] as? String == "DISTRICT#district-1")
        #expect(store.getCallCount == 1)
    }

    @Test("型指定の単一キー取得は任意のキー名を尊重する")
    func getByGenericKey() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        var received: [String: Codable] = [:]
        let store = DataStoreMock(getHandler: { keys, _ in
            received = keys
            return try encodeForDataStore(Record(district))
        })

        let result: Record<District>? = try await store.get(
            key: 2026, keyName: "year", as: Record<District>.self
        )

        #expect(result?.content == district)
        #expect(received["year"] as? Int == 2026)
        #expect(received.count == 1)
    }

    @Test("PKとSKによる削除は両方の完全一致キーを渡す")
    func deleteByCompositeKey() async throws {
        var received: [String: Codable] = [:]
        let store = DataStoreMock(deleteHandler: { keys in received = keys })

        try await store.delete(pk: "FESTIVAL#festival-1", sk: "DISTRICT#district-1")

        #expect(received["pk"] as? String == "FESTIVAL#festival-1")
        #expect(received["sk"] as? String == "DISTRICT#district-1")
        #expect(store.deleteCallCount == 1)
    }

    @Test("型指定の単一キー削除は型とキー名を保ったまま呼び出す")
    func deleteByGenericKey() async throws {
        var received: [String: Codable] = [:]
        let store = DataStoreMock(deleteHandler: { keys in received = keys })

        try await store.delete(key: 2026, keyName: "year")

        #expect(received["year"] as? Int == 2026)
        #expect(received.count == 1)
        #expect(store.deleteCallCount == 1)
    }

    @Test("省略形のScanはignoreDecodeErrorをfalseで呼び出す")
    func scanDefaultsToStrictDecode() async throws {
        var receivedIgnoreDecode = true
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let store = DataStoreMock(scanHandler: { ignore, _ in
            receivedIgnoreDecode = ignore
            return try encodeForDataStore([Record(district)])
        })

        let result: [Record<District>] = try await store.scan(Record<District>.self)

        #expect(result.map(\.content) == [district])
        #expect(!receivedIgnoreDecode)
        #expect(store.scanCallCount == 1)
    }

    @Test("単一QueryConditionの省略形はフィルタなしで呼び出す")
    func queryBySingleCondition() async throws {
        var capturedFilters: [FilterCondition] = []
        var capturedConditions: [QueryCondition] = []
        let store = DataStoreMock(queryHandler: { _, conditions, filters, _, _, _ in
            capturedConditions = conditions
            capturedFilters = filters
            return try encodeForDataStore([Record<District>]())
        })

        let result: [Record<District>] = try await store.query(
            keyCondition: .equals("pk", "FESTIVAL#festival-1"),
            as: Record<District>.self
        )

        #expect(result.isEmpty)
        #expect(capturedConditions.count == 1)
        #expect(capturedFilters.isEmpty)
        #expect(store.queryCallCount == 1)
    }

    @Test("単一キーとフィルタの省略形はページ条件を欠落させない")
    func queryByKeyAndFilter() async throws {
        var indexName: String?
        var conditions: [QueryCondition] = []
        var filters: [FilterCondition] = []
        var limit: Int?
        var ascending = true
        let store = DataStoreMock(queryHandler: { index, keys, queryFilters, max, asc, _ in
            indexName = index
            conditions = keys
            filters = queryFilters
            limit = max
            ascending = asc
            return try encodeForDataStore([Record<District>]())
        })

        _ = try await store.query(
            indexName: "index-TYPE",
            keyCondition: .equals("type", "DISTRICT"),
            filter: .contains("name", "district"),
            limit: 5,
            ascending: false,
            as: Record<District>.self
        )

        #expect(indexName == "index-TYPE")
        #expect(conditions.count == 1)
        #expect(filters.count == 1)
        #expect(limit == 5)
        #expect(!ascending)
    }

    @Test("queryConditionsの別名オーバーロードは複数条件をそのまま委譲する")
    func queryByMultipleConditionsAlias() async throws {
        var conditions: [QueryCondition] = []
        var filters: [FilterCondition] = []
        let store = DataStoreMock(queryHandler: { _, keys, filterValues, _, _, _ in
            conditions = keys
            filters = filterValues
            return try encodeForDataStore([Record<District>]())
        })

        _ = try await store.query(
            queryConditions: [
                .equals("pk", "FESTIVAL#festival-1"),
                .beginsWith("sk", "DISTRICT#")
            ],
            filterConditions: [.equals("type", "DISTRICT")],
            as: Record<District>.self
        )

        #expect(conditions.count == 2)
        #expect(filters.count == 1)
        #expect(store.queryCallCount == 1)
    }

    @Test("依存差し替えされたDataStoreFactoryは目的テーブル名を受け取る")
    func injectedFactoryReceivesTableName() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let store = DataStoreMock(queryHandler: { _, _, _, _, _, _ in
            try encodeForDataStore([Record(district)])
        })
        let repository = withDependencies {
            $0.dataStoreFactory = { name in
                #expect(name == "matool")
                return store
            }
        } operation: { DistrictRepository() }

        #expect(try await repository.get(id: district.id) == district)
    }
    @Test("強整合指定のPKとSK取得はDataStoreの標準取得へ正しいキーを渡す")
    func consistentReadByPKAndSKDelegatesToGet() async throws {
        var keys: [String: Codable] = [:]
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let store = DataStoreMock(getHandler: { captured, _ in
            keys = captured
            return try encodeForDataStore(Record(district))
        })

        let fetched: Record<District>? = try await store.get(
            pk: "FESTIVAL#festival-1",
            sk: "DISTRICT#district-1",
            consistentRead: true,
            as: Record<District>.self
        )

        #expect(fetched?.content == district)
        #expect(keys["pk"] as? String == "FESTIVAL#festival-1")
        #expect(keys["sk"] as? String == "DISTRICT#district-1")
        #expect(store.getCallCount == 1)
    }

}
