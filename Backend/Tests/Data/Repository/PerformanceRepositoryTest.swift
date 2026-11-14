import Dependencies
import Shared
import Testing
@testable import Backend

struct PerformanceRepositoryTest {
    @Test
    func query_正常_地区配下を返す() async throws {
        let performance = Performance.mock(id: "performance-1", districtId: "district-1")
        var lastCalledKeyConditions: [QueryCondition] = []

        let dataStore = DataStoreMock(
            queryHandler: { _, keyConditions, _, _, _, _ in
                lastCalledKeyConditions = keyConditions
                return try encodeForDataStore([Record(performance)])
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.query(by: "district-1")

        #expect(result == [performance])
        #expect(dataStore.queryCallCount == 1)
        #expect(lastCalledKeyConditions.count == 2)
    }

    @Test
    func delete_正常_pkとskで削除する() async throws {
        let item = Performance.mock(id: "performance-1", districtId: "district-1")
        var lastCalledKeys: [String: Codable] = [:]

        let dataStore = DataStoreMock(
            deleteHandler: { keys in
                lastCalledKeys = keys
            }
        )
        let subject = make(dataStore: dataStore)

        try await subject.delete(item)

        #expect(dataStore.deleteCallCount == 1)
        #expect((lastCalledKeys["pk"] as? String) == "DISTRICT#district-1")
        #expect((lastCalledKeys["sk"] as? String) == "PERFORMANCE#performance-1")
    }

    @Test
    func get_異常_依存エラーを透過() async {
        let dataStore = DataStoreMock(
            queryHandler: { _, _, _, _, _, _ in throw TestError.intentional }
        )
        let subject = make(dataStore: dataStore)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.get(id: "performance-1")
        }
    }
    @Test("ID検索はTYPEインデックスから対象の余興を返す")
    func get_正常_余興を取得する() async throws {
        let performance = Performance.mock(id: "performance-1", districtId: "district-1")
        var capturedIndex: String?
        let store = DataStoreMock(queryHandler: { index, _, _, _, _, _ in
            capturedIndex = index
            return try encodeForDataStore([Record(performance)])
        })
        let repository = make(dataStore: store)

        #expect(try await repository.get(id: performance.id) == performance)
        #expect(capturedIndex == "index-PERFORMANCE")
        #expect(store.queryCallCount == 1)
    }

    @Test("余興更新は地区・余興IDを含むレコードを保存する")
    func put_正常_余興を更新する() async throws {
        let item = Performance.mock(id: "performance-1", districtId: "district-1")
        var saved: Record<Performance>?
        let store = DataStoreMock(putHandler: { record in
            saved = try decodeFromEncodable(record, as: Record<Performance>.self)
        })
        let repository = make(dataStore: store)

        let result = try await repository.put(item)

        #expect(result == item)
        #expect(saved?.pk == "DISTRICT#district-1")
        #expect(saved?.sk == "PERFORMANCE#performance-1")
        #expect(saved?.content == item)
        #expect(store.putCallCount == 1)
    }

    @Test("余興登録は新しいレコードの値をそのまま返す")
    func post_正常_余興を追加する() async throws {
        let item = Performance.mock(id: "created", districtId: "district-1")
        var saved: Record<Performance>?
        let store = DataStoreMock(putHandler: { record in
            saved = try decodeFromEncodable(record, as: Record<Performance>.self)
        })
        let repository = make(dataStore: store)

        #expect(try await repository.post(item) == item)
        #expect(saved?.sk == "PERFORMANCE#created")
        #expect(store.putCallCount == 1)
    }

    @Test("リポジトリDIはテスト用の依存へ差し替えられる")
    func dependencyAccessorUsesInjectedStore() async throws {
        let item = Performance.mock(id: "test", districtId: "district-1")
        let store = DataStoreMock(queryHandler: { _, _, _, _, _, _ in
            try encodeForDataStore([Record(item)])
        })
        let repository = withDependencies {
            $0.performanceRepository = make(dataStore: store)
        } operation: {
            @Dependency(\.performanceRepository) var selected
            return selected
        }

        #expect(try await repository.get(id: item.id) == item)
        #expect(store.queryCallCount == 1)
    }

}

private extension PerformanceRepositoryTest {
    func make(dataStore: DataStoreMock = .init()) -> PerformanceRepository {
        withDependencies {
            $0[DataStoreFactoryKey.self] = { _ in dataStore }
        } operation: {
            PerformanceRepository()
        }
    }
}
