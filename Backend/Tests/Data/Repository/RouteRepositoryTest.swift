import Dependencies
import Shared
import Testing
@testable import Backend

struct RouteRepositoryTest {
    @Test
    func get_正常_TYPEインデックス検索で先頭を返す() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1", periodId: "period-1")
        var lastCalledIndexName: String?
        var lastCalledKeyConditions: [QueryCondition] = []

        let dataStore = DataStoreMock(
            queryHandler: { indexName, keyConditions, _, _, _, _ in
                lastCalledIndexName = indexName
                lastCalledKeyConditions = keyConditions
                return try encodeForDataStore([RouteRecordPayload(route, date: .init(year: 2026, month: 2, day: 22))])
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.get(id: route.id)

        #expect(result == route)
        #expect(dataStore.queryCallCount == 1)
        #expect(lastCalledIndexName == "index-TYPE")
        #expect(lastCalledKeyConditions.contains(where: { isEquals($0, field: "type", value: "ROUTE") }))
        #expect(lastCalledKeyConditions.contains(where: { isEquals($0, field: "sk", value: "ROUTE#\(route.id)") }))
    }

    @Test
    func query_正常_地区配下を取得する() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1", periodId: "period-1")
        var lastCalledIndexName: String?
        var lastCalledKeyConditions: [QueryCondition] = []

        let dataStore = DataStoreMock(
            queryHandler: { indexName, keyConditions, _, _, _, _ in
                lastCalledIndexName = indexName
                lastCalledKeyConditions = keyConditions
                return try encodeForDataStore([RouteRecordPayload(route, date: .init(year: 2026, month: 2, day: 22))])
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.query(by: route.districtId)

        #expect(result == [route])
        #expect(dataStore.queryCallCount == 1)
        #expect(lastCalledIndexName == nil)
        #expect(lastCalledKeyConditions.contains(where: { isEquals($0, field: "pk", value: "DISTRICT#\(route.districtId)") }))
        #expect(lastCalledKeyConditions.contains(where: { isBeginsWith($0, field: "sk", prefix: "ROUTE#") }))
    }

    @Test
    func query_正常_年指定でDATEインデックス検索する() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1", periodId: "period-1")
        var lastCalledIndexName: String?
        var lastCalledKeyConditions: [QueryCondition] = []

        let dataStore = DataStoreMock(
            queryHandler: { indexName, keyConditions, _, _, _, _ in
                lastCalledIndexName = indexName
                lastCalledKeyConditions = keyConditions
                return try encodeForDataStore([RouteRecordPayload(route, date: .init(year: 2026, month: 2, day: 22))])
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.query(by: route.districtId, year: 2026)

        #expect(result == [route])
        #expect(dataStore.queryCallCount == 1)
        #expect(lastCalledIndexName == "index-DATE")
        #expect(lastCalledKeyConditions.contains(where: { isEquals($0, field: "pk", value: "DISTRICT#\(route.districtId)") }))
        #expect(lastCalledKeyConditions.contains(where: { isBeginsWith($0, field: "date", prefix: "ROUTE#DATE#2026") }))
    }

    @Test
    func post_正常_日程日付を解決してputする() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1", periodId: "period-1")
        let period = Period.mock(id: route.periodId, festivalId: "festival-1", date: .init(year: 2026, month: 2, day: 22))
        var lastCalledPeriodId: String?
        var lastCalledRecord: RouteRecordPayload?

        let periodRepository = PeriodRepositoryMock(
            getHandler: { id in
                lastCalledPeriodId = id
                return period
            }
        )
        let dataStore = DataStoreMock(
            putHandler: { item in
                lastCalledRecord = try decodeFromEncodable(item, as: RouteRecordPayload.self)
            }
        )
        let subject = make(dataStore: dataStore, periodRepository: periodRepository)

        let result = try await subject.post(route)

        #expect(result == route)
        #expect(periodRepository.getCallCount == 1)
        #expect(lastCalledPeriodId == route.periodId)
        #expect(dataStore.putCallCount == 1)
        #expect(lastCalledRecord?.content == route)
        #expect(lastCalledRecord?.pk == "DISTRICT#\(route.districtId)")
        #expect(lastCalledRecord?.sk == "ROUTE#\(route.id)")
        #expect(lastCalledRecord?.date == "ROUTE#DATE#2026-02-22")
    }

    @Test
    func put_正常_日程日付を解決してputする() async throws {
        let route = Route.mock(id: "route-2", districtId: "district-1", periodId: "period-2")
        let period = Period.mock(id: route.periodId, festivalId: "festival-1", date: .init(year: 2026, month: 3, day: 1))
        var lastCalledPeriodId: String?
        var lastCalledRecord: RouteRecordPayload?

        let periodRepository = PeriodRepositoryMock(
            getHandler: { id in
                lastCalledPeriodId = id
                return period
            }
        )
        let dataStore = DataStoreMock(
            putHandler: { item in
                lastCalledRecord = try decodeFromEncodable(item, as: RouteRecordPayload.self)
            }
        )
        let subject = make(dataStore: dataStore, periodRepository: periodRepository)

        let result = try await subject.put(route)

        #expect(result == route)
        #expect(periodRepository.getCallCount == 1)
        #expect(lastCalledPeriodId == route.periodId)
        #expect(dataStore.putCallCount == 1)
        #expect(lastCalledRecord?.content == route)
        #expect(lastCalledRecord?.pk == "DISTRICT#\(route.districtId)")
        #expect(lastCalledRecord?.sk == "ROUTE#\(route.id)")
        #expect(lastCalledRecord?.date == "ROUTE#DATE#2026-03-01")
    }

    @Test
    func delete_正常_対象ありでpkとskを削除する() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1", periodId: "period-1")
        var lastCalledDeleteKeys: [String: Codable] = [:]

        let dataStore = DataStoreMock(
            deleteHandler: { keys in
                lastCalledDeleteKeys = keys
            },
            queryHandler: { _, _, _, _, _, _ in
                try encodeForDataStore([RouteRecordPayload(route, date: .init(year: 2026, month: 2, day: 22))])
            }
        )
        let subject = make(dataStore: dataStore)

        try await subject.delete(id: route.id)

        #expect(dataStore.queryCallCount == 1)
        #expect(dataStore.deleteCallCount == 1)
        #expect((lastCalledDeleteKeys["pk"] as? String) == "DISTRICT#\(route.districtId)")
        #expect((lastCalledDeleteKeys["sk"] as? String) == "ROUTE#\(route.id)")
    }

    @Test
    func delete_正常_対象なしでは削除しない() async throws {
        let dataStore = DataStoreMock(
            queryHandler: { _, _, _, _, _, _ in
                try encodeForDataStore([RouteRecordPayload]())
            }
        )
        let subject = make(dataStore: dataStore)

        try await subject.delete(id: "route-1")

        #expect(dataStore.queryCallCount == 1)
        #expect(dataStore.deleteCallCount == 0)
    }

    @Test
    func get_異常_依存エラーを透過() async {
        let dataStore = DataStoreMock(
            queryHandler: { _, _, _, _, _, _ in throw TestError.intentional }
        )
        let subject = make(dataStore: dataStore)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.get(id: "route-1")
        }
    }

    @Test
    func put_異常_依存エラーを透過() async {
        let periodRepository = PeriodRepositoryMock(
            getHandler: { _ in .mock(id: "period-1", date: .init(year: 2026, month: 2, day: 22)) }
        )
        let dataStore = DataStoreMock(
            putHandler: { _ in throw TestError.intentional }
        )
        let subject = make(dataStore: dataStore, periodRepository: periodRepository)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.put(.mock(id: "route-1", districtId: "district-1", periodId: "period-1"))
        }
    }

    @Test
    func post_異常_関連日程未登録でnotFoundを返す() async {
        let periodRepository = PeriodRepositoryMock(
            getHandler: { _ in nil }
        )
        let subject = make(periodRepository: periodRepository)

        await #expect(throws: Error.notFound("指定されたルートに合致する日程が取得できませんでした。")) {
            _ = try await subject.post(.mock(id: "route-1", districtId: "district-1", periodId: "period-1"))
        }
    }

    @Test
    func post_異常_日程取得の依存エラーを透過() async {
        let periodRepository = PeriodRepositoryMock(
            getHandler: { _ in throw TestError.intentional }
        )
        let subject = make(periodRepository: periodRepository)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.post(.mock(id: "route-1", districtId: "district-1", periodId: "period-1"))
        }
    }
}

private extension RouteRepositoryTest {
    func make(
        dataStore: DataStoreMock = .init(),
        periodRepository: PeriodRepositoryMock = .init()
    ) -> RouteRepository {
        withDependencies {
            $0[DataStoreFactoryKey.self] = { _ in dataStore }
            $0[PeriodRepositoryKey.self] = periodRepository
        } operation: {
            RouteRepository()
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

private struct RouteRecordPayload: Codable {
    let pk: String
    let sk: String
    let type: String
    let date: String
    let content: Route

    init(_ content: Route, date: SimpleDate) {
        self.pk = "DISTRICT#\(content.districtId)"
        self.sk = "ROUTE#\(content.id)"
        self.type = "ROUTE"
        self.date = "ROUTE#DATE#\(date.sortableKey)"
        self.content = content
    }
}
