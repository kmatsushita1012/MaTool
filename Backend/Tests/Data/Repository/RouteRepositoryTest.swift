import Foundation
import Dependencies
import Shared
import Testing
@testable import Backend

struct RouteRepositoryTest {
    @Test
    func get_IDインデックスでRouteを取得する() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1", periodId: "period-1")
        var indexName: String?
        var conditions: [QueryCondition] = []
        let store = DataStoreMock(queryHandler: { index, keys, _, _, _, _ in
            indexName = index
            conditions = keys
            return try JSONEncoder().encode([RouteRecord(route, editionId: "edition-1", date: .init(year: 2026, month: 2, day: 22))])
        })
        let repository = make(dataStore: store)

        #expect(try await repository.get(id: route.id) == route)
        #expect(indexName == "index-type-id")
        #expect(conditions.contains(where: { isEquals($0, field: "type", value: "ROUTE") }))
        #expect(conditions.contains(where: { isEquals($0, field: "id", value: route.id) }))
    }

    @Test
    func query_地区配下のRouteを取得する() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        var conditions: [QueryCondition] = []
        let store = DataStoreMock(queryHandler: { _, keys, _, _, _, _ in
            conditions = keys
            return try JSONEncoder().encode([RouteRecord(route, editionId: "edition-1", date: .init(year: 2026, month: 2, day: 22))])
        })
        let repository = make(dataStore: store)

        #expect(try await repository.query(by: route.districtId) == [route])
        #expect(conditions.contains(where: { isEquals($0, field: "pk", value: "DISTRICT#district-1") }))
        #expect(conditions.contains(where: { isBeginsWith($0, field: "sk", prefix: "ROUTE#") }))
    }

    @Test
    func query_Editionを指定してRouteを取得する() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        var conditions: [QueryCondition] = []
        var indexName: String?
        let store = DataStoreMock(queryHandler: { index, keys, _, _, _, _ in
            indexName = index
            conditions = keys
            return try JSONEncoder().encode([RouteRecord(route, editionId: "edition-1", date: .init(year: 2026, month: 2, day: 22))])
        })
        let repository = make(dataStore: store)

        #expect(try await repository.query(by: route.districtId, editionId: "edition-1") == [route])
        #expect(indexName == nil)
        #expect(conditions.contains(where: { isEquals($0, field: "pk", value: "DISTRICT#district-1") }))
        #expect(conditions.contains(where: { isBeginsWith($0, field: "sk", prefix: "ROUTE#edition-1#") }))
    }

    @Test
    func query_年度検索ではDATEインデックスを維持する() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        var indexName: String?
        var conditions: [QueryCondition] = []
        let store = DataStoreMock(queryHandler: { index, keys, _, _, _, _ in
            indexName = index
            conditions = keys
            return try JSONEncoder().encode([RouteRecord(route, editionId: "edition-1", date: .init(year: 2026, month: 2, day: 22))])
        })
        let repository = make(dataStore: store)

        #expect(try await repository.query(by: route.districtId, year: 2026) == [route])
        #expect(indexName == "index-DATE")
        #expect(conditions.contains(where: { isEquals($0, field: "pk", value: "DISTRICT#district-1") }))
        #expect(conditions.contains(where: { isBeginsWith($0, field: "date", prefix: "ROUTE#DATE#2026") }))
    }

    @Test
    func post_PeriodのEditionを使ったキーで保存する() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1", periodId: "period-1")
        let period = Period.mock(id: route.periodId, festivalId: "festival-1", editionId: "edition-1", date: .init(year: 2026, month: 2, day: 22))
        var saved: RouteRecord?
        let store = DataStoreMock(putHandler: { item in saved = try decodeFromEncodable(item, as: RouteRecord.self) })
        let repository = make(
            dataStore: store,
            periodRepository: .init(getHandler: { _ in period })
        )

        #expect(try await repository.post(route) == route)
        #expect(saved?.pk == "DISTRICT#district-1")
        #expect(saved?.sk == "ROUTE#edition-1#route-1")
        #expect(saved?.id == route.id)
        #expect(saved?.date == "ROUTE#DATE#2026-02-22")
        #expect(saved?.content == route)
    }

    @Test
    func put_所属Edition変更時は旧キーを削除して保存する() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1", periodId: "period-new")
        let period = Period.mock(id: route.periodId, festivalId: "festival-1", editionId: "edition-new")
        let oldRecord = RouteRecord(route, editionId: "edition-old", date: .init(year: 2026, month: 2, day: 22))
        var saved: RouteRecord?
        var deleted: [String: Codable] = [:]
        let store = DataStoreMock(
            putHandler: { item in saved = try decodeFromEncodable(item, as: RouteRecord.self) },
            deleteHandler: { deleted = $0 },
            queryHandler: { _, _, _, _, _, _ in try JSONEncoder().encode([oldRecord]) }
        )
        let repository = make(dataStore: store, periodRepository: .init(getHandler: { _ in period }))

        _ = try await repository.put(route)

        #expect(deleted["pk"] as? String == "DISTRICT#district-1")
        #expect(deleted["sk"] as? String == "ROUTE#edition-old#route-1")
        #expect(saved?.sk == "ROUTE#edition-new#route-1")
        #expect(store.queryCallCount == 1)
    }

    @Test
    func put_同じEdition内の日付更新では旧キーを削除しない() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1", periodId: "period-1")
        let period = Period.mock(id: route.periodId, festivalId: "festival-1", editionId: "edition-1", date: .init(year: 2027, month: 3, day: 1))
        let oldRecord = RouteRecord(route, editionId: "edition-1", date: .init(year: 2026, month: 2, day: 22))
        var saved: RouteRecord?
        let store = DataStoreMock(
            putHandler: { item in saved = try decodeFromEncodable(item, as: RouteRecord.self) },
            queryHandler: { _, _, _, _, _, _ in try JSONEncoder().encode([oldRecord]) }
        )
        let repository = make(dataStore: store, periodRepository: .init(getHandler: { _ in period }))

        _ = try await repository.put(route)

        #expect(saved?.sk == "ROUTE#edition-1#route-1")
        #expect(saved?.date == "ROUTE#DATE#2027-03-01")
        #expect(store.deleteCallCount == 0)
    }

    @Test
    func post_地区とPeriodの祭典が異なる場合は保存しない() async {
        let route = Route.mock(id: "route-1", districtId: "district-1", periodId: "period-1")
        let period = Period.mock(id: route.periodId, festivalId: "festival-2", editionId: "edition-2")
        let store = DataStoreMock()
        let repository = make(
            dataStore: store,
            districtRepository: .init(queryHandler: { _ in [.mock(id: route.districtId, festivalId: "festival-1")] }),
            periodRepository: .init(getHandler: { _ in period })
        )

        await #expect(throws: Error.notFound("指定されたルートに合致する地区が取得できませんでした。")) {
            _ = try await repository.post(route)
        }
        #expect(store.putCallCount == 0)
    }

    @Test
    func post_EditionのないPeriodは拒否する() async {
        let route = Route.mock(id: "route-1", districtId: "district-1", periodId: "period-1")
        let period = Period(id: route.periodId, festivalId: "festival-1", date: .init(year: 2026, month: 2, day: 22))
        let store = DataStoreMock()
        let repository = make(dataStore: store, periodRepository: .init(getHandler: { _ in period }))

        await #expect(throws: Error.badRequest("ルートの日程にEditionが設定されていません。")) {
            _ = try await repository.post(route)
        }
        #expect(store.putCallCount == 0)
    }

    @Test
    func delete_IDから実際の主キーを削除する() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let record = RouteRecord(route, editionId: "edition-1", date: .init(year: 2026, month: 2, day: 22))
        var deleted: [String: Codable] = [:]
        let store = DataStoreMock(
            deleteHandler: { deleted = $0 },
            queryHandler: { _, _, _, _, _, _ in try JSONEncoder().encode([record]) }
        )
        let repository = make(dataStore: store)

        try await repository.delete(id: route.id)

        #expect(deleted["pk"] as? String == "DISTRICT#district-1")
        #expect(deleted["sk"] as? String == "ROUTE#edition-1#route-1")
    }

    @Test
    func delete_Routeの地区と一致するレコードだけを削除する() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let wrongDistrictRecord = RouteRecord(.mock(id: route.id, districtId: "district-2"), editionId: "edition-1", date: .init(year: 2026, month: 2, day: 22))
        var deleted: [String: Codable] = [:]
        let store = DataStoreMock(
            deleteHandler: { deleted = $0 },
            queryHandler: { _, _, _, _, _, _ in try JSONEncoder().encode([wrongDistrictRecord]) }
        )
        let repository = make(dataStore: store)

        try await repository.delete(route)

        #expect(store.deleteCallCount == 0)
        #expect(deleted.isEmpty)
    }

    @Test
    func get_依存エラーを透過する() async {
        let repository = make(dataStore: .init(queryHandler: { _, _, _, _, _, _ in throw TestError.intentional }))

        await #expect(throws: TestError.intentional) {
            _ = try await repository.get(id: "route-1")
        }
    }
}

private extension RouteRepositoryTest {
    func make(
        dataStore: DataStoreMock = .init(),
        districtRepository: DistrictRepositoryMock = .init(
            queryHandler: { festivalId in [.mock(id: "district-1", festivalId: festivalId)] }
        ),
        periodRepository: PeriodRepositoryMock = .init()
    ) -> RouteRepository {
        withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[PeriodRepositoryKey.self] = periodRepository
        } operation: {
            RouteRepository()
        }
    }

    func isEquals(_ condition: QueryCondition, field: String, value: String) -> Bool {
        guard case let .equals(actualField, actualValue) = condition,
              let actualValue = actualValue as? String else { return false }
        return actualField == field && actualValue == value
    }

    func isBeginsWith(_ condition: QueryCondition, field: String, prefix: String) -> Bool {
        guard case let .beginsWith(actualField, actualPrefix) = condition else { return false }
        return actualField == field && actualPrefix == prefix
    }
}
