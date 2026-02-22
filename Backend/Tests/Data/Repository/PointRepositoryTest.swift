import Dependencies
import Shared
import Testing
@testable import Backend

struct PointRepositoryTest {
    @Test
    func get_正常_TYPEインデックス検索で先頭を返す() async throws {
        let point = Point.mock(id: "point-1", routeId: "route-1")
        var lastCalledIndexName: String?
        var lastCalledKeyConditions: [QueryCondition] = []

        let dataStore = DataStoreMock(
            queryHandler: { indexName, keyConditions, _, _, _, _ in
                lastCalledIndexName = indexName
                lastCalledKeyConditions = keyConditions
                return try encodeForDataStore([Record(point)])
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.get(id: point.id)

        #expect(result == point)
        #expect(dataStore.queryCallCount == 1)
        #expect(lastCalledIndexName == "index-TYPE")
        #expect(lastCalledKeyConditions.contains(where: { isEquals($0, field: "type", value: "POINT") }))
        #expect(lastCalledKeyConditions.contains(where: { isBeginsWith($0, field: "sk", prefix: "POINT#") }))
    }

    @Test
    func query_正常_ルート配下を昇順で取得する() async throws {
        let point = Point.mock(id: "point-1", routeId: "route-1")
        var lastCalledAscending: Bool?
        var lastCalledKeyConditions: [QueryCondition] = []

        let dataStore = DataStoreMock(
            queryHandler: { _, keyConditions, _, _, ascending, _ in
                lastCalledKeyConditions = keyConditions
                lastCalledAscending = ascending
                return try encodeForDataStore([Record(point)])
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.query(by: point.routeId)

        #expect(result == [point])
        #expect(dataStore.queryCallCount == 1)
        #expect(lastCalledAscending == true)
        #expect(lastCalledKeyConditions.contains(where: { isEquals($0, field: "pk", value: "ROUTE#\(point.routeId)") }))
        #expect(lastCalledKeyConditions.contains(where: { isBeginsWith($0, field: "sk", prefix: "POINT#") }))
    }

    @Test
    func put_正常_レコード化してputする() async throws {
        let point = Point.mock(id: "point-1", routeId: "route-1")
        var lastCalledRecord: Record<Point>?

        let dataStore = DataStoreMock(
            putHandler: { item in
                lastCalledRecord = try decodeFromEncodable(item, as: Record<Point>.self)
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.put(point)

        #expect(result == point)
        #expect(dataStore.putCallCount == 1)
        #expect(lastCalledRecord?.content == point)
        #expect(lastCalledRecord?.pk == "ROUTE#\(point.routeId)")
        #expect(lastCalledRecord?.sk == "POINT#\(point.id)")
    }

    @Test
    func post_正常_レコード化してputする() async throws {
        let point = Point.mock(id: "point-2", routeId: "route-1")
        var lastCalledRecord: Record<Point>?

        let dataStore = DataStoreMock(
            putHandler: { item in
                lastCalledRecord = try decodeFromEncodable(item, as: Record<Point>.self)
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.post(point)

        #expect(result == point)
        #expect(dataStore.putCallCount == 1)
        #expect(lastCalledRecord?.content == point)
        #expect(lastCalledRecord?.pk == "ROUTE#\(point.routeId)")
        #expect(lastCalledRecord?.sk == "POINT#\(point.id)")
    }

    @Test
    func delete_正常_pkとskで削除する() async throws {
        let point = Point.mock(id: "point-1", routeId: "route-1")
        var lastCalledKeys: [String: Codable] = [:]

        let dataStore = DataStoreMock(
            deleteHandler: { keys in
                lastCalledKeys = keys
            }
        )
        let subject = make(dataStore: dataStore)

        try await subject.delete(point)

        #expect(dataStore.deleteCallCount == 1)
        #expect((lastCalledKeys["pk"] as? String) == "ROUTE#\(point.routeId)")
        #expect((lastCalledKeys["sk"] as? String) == "POINT#\(point.id)")
    }

    @Test
    func delete_正常_ルート配下を全件削除する() async throws {
        let point1 = Point.mock(id: "point-1", routeId: "route-1")
        let point2 = Point.mock(id: "point-2", routeId: "route-1")
        var lastCalledDeleteKeys: [String] = []

        let dataStore = DataStoreMock(
            deleteHandler: { keys in
                let pk = keys["pk"] as? String ?? ""
                let sk = keys["sk"] as? String ?? ""
                lastCalledDeleteKeys.append("\(pk)|\(sk)")
            },
            queryHandler: { _, _, _, _, _, _ in
                try encodeForDataStore([Record(point1), Record(point2)])
            }
        )
        let subject = make(dataStore: dataStore)

        try await subject.delete(by: "route-1")

        #expect(dataStore.queryCallCount == 1)
        #expect(dataStore.deleteCallCount == 2)
        #expect(lastCalledDeleteKeys.contains("ROUTE#route-1|POINT#point-1"))
        #expect(lastCalledDeleteKeys.contains("ROUTE#route-1|POINT#point-2"))
    }

    @Test
    func put_異常_依存エラーを透過() async {
        let dataStore = DataStoreMock(
            putHandler: { _ in throw TestError.intentional }
        )
        let subject = make(dataStore: dataStore)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.put(.mock(id: "point-1", routeId: "route-1"))
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

private extension PointRepositoryTest {
    func make(dataStore: DataStoreMock = .init()) -> PointRepository {
        withDependencies {
            $0[DataStoreFactoryKey.self] = { _ in dataStore }
        } operation: {
            PointRepository()
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
