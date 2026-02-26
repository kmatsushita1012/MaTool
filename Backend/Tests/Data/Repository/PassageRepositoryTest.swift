import Dependencies
import Shared
import Testing
@testable import Backend
import DependenciesTestSupport

extension RepositoryTest{
    @Suite struct Passage {}
}

extension RepositoryTest.Passage {
    @Test
    func get_正常_TYPEインデックス検索で先頭を返す() async throws {
        let passage = RoutePassage.mock(id: "passage-1", routeId: "route-1", districtId: "district-1")
        var lastCalledIndexName: String?
        var lastCalledKeyConditions: [QueryCondition] = []

        let dataStore = DataStoreMock(
            queryHandler: { indexName, keyConditions, _, _, _, _ in
                lastCalledIndexName = indexName
                lastCalledKeyConditions = keyConditions
                return try encodeForDataStore([Record(passage)])
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.get(id: passage.id)

        #expect(result == passage)
        #expect(dataStore.queryCallCount == 1)
        #expect(lastCalledIndexName == "index-TYPE")
        #expect(lastCalledKeyConditions.contains(where: { isEquals($0, field: "type", value: "ROUTEPASSAGE") }))
        #expect(lastCalledKeyConditions.contains(where: { isEquals($0, field: "sk", value: "PASSAGE#\(passage.id)") }))
    }

    @Test
    func query_正常_ルート配下を昇順で取得する() async throws {
        let passage = RoutePassage.mock(id: "passage-1", routeId: "route-1", districtId: "district-1")
        var lastCalledAscending: Bool?
        var lastCalledKeyConditions: [QueryCondition] = []

        let dataStore = DataStoreMock(
            queryHandler: { _, keyConditions, _, _, ascending, _ in
                lastCalledKeyConditions = keyConditions
                lastCalledAscending = ascending
                return try encodeForDataStore([Record(passage)])
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.query(by: passage.routeId)

        #expect(result == [passage])
        #expect(dataStore.queryCallCount == 1)
        #expect(lastCalledAscending == true)
        #expect(lastCalledKeyConditions.contains(where: { isEquals($0, field: "pk", value: "ROUTE#\(passage.routeId)") }))
        #expect(lastCalledKeyConditions.contains(where: { isBeginsWith($0, field: "sk", prefix: "PASSAGE#") }))
    }

    @Test
    func put_正常_レコード化してputする() async throws {
        let passage = RoutePassage.mock(id: "passage-1", routeId: "route-1", districtId: "district-1")
        var lastCalledRecord: Record<RoutePassage>?

        let dataStore = DataStoreMock(
            putHandler: { item in
                lastCalledRecord = try decodeFromEncodable(item, as: Record<RoutePassage>.self)
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.put(passage)

        #expect(result == passage)
        #expect(dataStore.putCallCount == 1)
        #expect(lastCalledRecord?.content == passage)
        #expect(lastCalledRecord?.pk == "ROUTE#\(passage.routeId)")
        #expect(lastCalledRecord?.sk == "PASSAGE#\(passage.id)")
    }

    @Test
    func post_正常_レコード化してputする() async throws {
        let passage = RoutePassage.mock(id: "passage-2", routeId: "route-1", districtId: "district-2")
        var lastCalledRecord: Record<RoutePassage>?

        let dataStore = DataStoreMock(
            putHandler: { item in
                lastCalledRecord = try decodeFromEncodable(item, as: Record<RoutePassage>.self)
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.post(passage)

        #expect(result == passage)
        #expect(dataStore.putCallCount == 1)
        #expect(lastCalledRecord?.content == passage)
        #expect(lastCalledRecord?.pk == "ROUTE#\(passage.routeId)")
        #expect(lastCalledRecord?.sk == "PASSAGE#\(passage.id)")
    }

    @Test
    func delete_正常_pkとskで削除する() async throws {
        let passage = RoutePassage.mock(id: "passage-1", routeId: "route-1", districtId: "district-1")
        var lastCalledKeys: [String: Codable] = [:]

        let dataStore = DataStoreMock(
            deleteHandler: { keys in
                lastCalledKeys = keys
            }
        )
        let subject = make(dataStore: dataStore)

        try await subject.delete(passage)

        #expect(dataStore.deleteCallCount == 1)
        #expect((lastCalledKeys["pk"] as? String) == "ROUTE#\(passage.routeId)")
        #expect((lastCalledKeys["sk"] as? String) == "PASSAGE#\(passage.id)")
    }

    @Test
    func delete_正常_ルート配下を全件削除する() async throws {
        let passage1 = RoutePassage.mock(id: "passage-1", routeId: "route-1", districtId: "district-1")
        let passage2 = RoutePassage.mock(id: "passage-2", routeId: "route-1", districtId: "district-2")
        var lastCalledDeleteKeys: [String] = []

        let dataStore = DataStoreMock(
            deleteHandler: { keys in
                let pk = keys["pk"] as? String ?? ""
                let sk = keys["sk"] as? String ?? ""
                lastCalledDeleteKeys.append("\(pk)|\(sk)")
            },
            queryHandler: { _, _, _, _, _, _ in
                try encodeForDataStore([Record(passage1), Record(passage2)])
            }
        )
        let subject = make(dataStore: dataStore)

        try await subject.delete(by: "route-1")

        #expect(dataStore.queryCallCount == 1)
        #expect(dataStore.deleteCallCount == 2)
        #expect(lastCalledDeleteKeys.contains("ROUTE#route-1|PASSAGE#passage-1"))
        #expect(lastCalledDeleteKeys.contains("ROUTE#route-1|PASSAGE#passage-2"))
    }

    @Test
    func post_異常_依存エラーを透過() async {
        let dataStore = DataStoreMock(
            putHandler: { _ in throw TestError.intentional }
        )
        let subject = make(dataStore: dataStore)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.post(.mock(id: "passage-1", routeId: "route-1", districtId: "district-1"))
        }
    }

    @Test
    func query_異常_依存エラーを透過() async {
        let dataStore = DataStoreMock(
            queryHandler: { _, _, _, _, _, _ in throw TestError.intentional }
        )
        let subject = make(dataStore: dataStore)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.query(by: "route-1")
        }
    }
}

private extension RepositoryTest.Passage {
    func make(dataStore: DataStoreMock = .init()) -> PassageRepository {
        withDependencies {
            $0[DataStoreFactoryKey.self] = { _ in dataStore }
        } operation: {
            PassageRepository()
        }
    }

    func isEquals(_ condition: QueryCondition, field: String, value: String) -> Bool {
        guard case let .equals(actualField, actualValue) = condition else { return false }
        guard let actual = actualValue as? String else { return false }
        return actualField == field && actual == value
    }

    func isBeginsWith(_ condition: QueryCondition, field: String, prefix: String) -> Bool {
        guard case let .beginsWith(actualField, actualPrefix) = condition else { return false }
        return actualField == field && actualPrefix == prefix
    }
}
