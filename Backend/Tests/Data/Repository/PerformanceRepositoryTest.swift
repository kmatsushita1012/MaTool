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
