import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct RouteUniqueHTTPTest {
    @Test
    func HTTP作成更新競合と同一ルート更新およびmarker解放を確認する() async throws {
        let store = RouteMemoryDataStore()
        let periods = [
            Period.mock(id: "period-a", festivalId: "festival-1"),
            Period.mock(id: "period-b", festivalId: "festival-1", date: .init(year: 2026, month: 2, day: 23)),
            Period.mock(id: "period-c", festivalId: "festival-1", date: .init(year: 2026, month: 2, day: 24))
        ]
        let routeA = Route.mock(id: "route-a", districtId: "district-1", periodId: "period-a")
        let routeB = Route.mock(id: "route-b", districtId: "district-1", periodId: "period-b")

        let createA = try await send(.post, path: "/districts/district-1/routes", route: routeA, store: store, periods: periods)
        #expect(createA.statusCode == 200)
        #expect(try RoutePack.from(createA.body).route == routeA)
        #expect(await store.route(id: routeA.id) == routeA)
        #expect(await store.markerOwner(districtId: routeA.districtId, periodId: routeA.periodId) == routeA.id)

        let duplicateCreate = try await send(
            .post,
            path: "/districts/district-1/routes",
            route: .mock(id: "route-duplicate", districtId: "district-1", periodId: "period-a"),
            store: store,
            periods: periods
        )
        #expect(duplicateCreate.statusCode == 409)
        #expect(duplicateCreate.body.contains("この地区・日程には既にルートが登録されています。"))
        #expect(await store.route(id: "route-duplicate") == nil)

        let createB = try await send(.post, path: "/districts/district-1/routes", route: routeB, store: store, periods: periods)
        #expect(createB.statusCode == 200)

        let duplicateUpdate = try await send(
            .put,
            path: "/routes/route-b",
            route: .mock(id: routeB.id, districtId: routeB.districtId, periodId: routeA.periodId),
            store: store,
            periods: periods
        )
        #expect(duplicateUpdate.statusCode == 409)
        #expect(await store.route(id: routeB.id) == routeB)
        #expect(await store.markerOwner(districtId: routeB.districtId, periodId: routeB.periodId) == routeB.id)

        let updateAInPlace = try await send(.put, path: "/routes/route-a", route: routeA, store: store, periods: periods)
        #expect(updateAInPlace.statusCode == 200)
        #expect(try RoutePack.from(updateAInPlace.body).route == routeA)
        #expect(await store.route(id: routeA.id) == routeA)

        let moveAtoC = try await send(
            .put,
            path: "/routes/route-a",
            route: .mock(id: routeA.id, districtId: routeA.districtId, periodId: "period-c"),
            store: store,
            periods: periods
        )
        #expect(moveAtoC.statusCode == 200)
        #expect(await store.markerOwner(districtId: routeA.districtId, periodId: routeA.periodId) == nil)
        #expect(await store.markerOwner(districtId: routeA.districtId, periodId: "period-c") == routeA.id)

        let reuseReleasedPair = try await send(
            .post,
            path: "/districts/district-1/routes",
            route: .mock(id: "route-c", districtId: "district-1", periodId: "period-a"),
            store: store,
            periods: periods
        )
        #expect(reuseReleasedPair.statusCode == 200)
        #expect(await store.route(id: "route-c")?.periodId == "period-a")
    }

    @Test
    func HTTP同時作成でも一意markerで一方だけ成功する() async throws {
        let store = RouteMemoryDataStore()
        let periods = [Period.mock(id: "period-a", festivalId: "festival-1")]
        let routeA = Route.mock(id: "route-a", districtId: "district-1", periodId: "period-a")
        let routeB = Route.mock(id: "route-b", districtId: "district-1", periodId: "period-a")

        async let responseA = try send(.post, path: "/districts/district-1/routes", route: routeA, store: store, periods: periods)
        async let responseB = try send(.post, path: "/districts/district-1/routes", route: routeB, store: store, periods: periods)
        let (actualA, actualB) = try await (responseA, responseB)

        #expect([actualA.statusCode, actualB.statusCode].filter { $0 == 200 }.count == 1)
        #expect([actualA.statusCode, actualB.statusCode].filter { $0 == 409 }.count == 1)
        let storedRoutes = await store.routes()
        #expect(storedRoutes.count == 1)
        #expect(await store.markerOwner(districtId: "district-1", periodId: "period-a") == storedRoutes.first?.id)
    }

    @Test
    func HTTP同一Routeの同時period更新で古いmarkerを残さない() async throws {
        let store = RouteMemoryDataStore()
        let periods = [
            Period.mock(id: "period-a", festivalId: "festival-1"),
            Period.mock(id: "period-b", festivalId: "festival-1", date: .init(year: 2026, month: 2, day: 23)),
            Period.mock(id: "period-c", festivalId: "festival-1", date: .init(year: 2026, month: 2, day: 24))
        ]
        let original = Route.mock(id: "route-a", districtId: "district-1", periodId: "period-a")
        let create = try await send(.post, path: "/districts/district-1/routes", route: original, store: store, periods: periods)
        #expect(create.statusCode == 200)

        async let updateB = try send(
            .put,
            path: "/routes/route-a",
            route: .mock(id: original.id, districtId: original.districtId, periodId: "period-b"),
            store: store,
            periods: periods
        )
        async let updateC = try send(
            .put,
            path: "/routes/route-a",
            route: .mock(id: original.id, districtId: original.districtId, periodId: "period-c"),
            store: store,
            periods: periods
        )
        let (responseB, responseC) = try await (updateB, updateC)

        #expect([200, 409].contains(responseB.statusCode))
        #expect([200, 409].contains(responseC.statusCode))
        let stored = try #require(await store.route(id: original.id))
        #expect(["period-b", "period-c"].contains(stored.periodId))
        #expect(await store.markerOwner(districtId: original.districtId, periodId: "period-a") == nil)
        #expect(await store.markerOwner(districtId: stored.districtId, periodId: stored.periodId) == stored.id)
        let otherPeriod = stored.periodId == "period-b" ? "period-c" : "period-b"
        #expect(await store.markerOwner(districtId: stored.districtId, periodId: otherPeriod) == nil)
    }

    @Test
    func legacyRouteは競合作成を拒否し同じrouteの更新でmarkerを作る() async throws {
        let store = RouteMemoryDataStore()
        let periods = [Period.mock(id: "period-a", festivalId: "festival-1")]
        let legacyRoute = Route.mock(id: "legacy-route", districtId: "district-1", periodId: "period-a")
        await store.seedLegacy(legacyRoute)

        let duplicate = try await send(
            .post,
            path: "/districts/district-1/routes",
            route: .mock(id: "new-route", districtId: "district-1", periodId: "period-a"),
            store: store,
            periods: periods
        )
        #expect(duplicate.statusCode == 409)
        #expect(await store.markerOwner(districtId: legacyRoute.districtId, periodId: legacyRoute.periodId) == nil)

        let update = try await send(.put, path: "/routes/legacy-route", route: legacyRoute, store: store, periods: periods)
        #expect(update.statusCode == 200)
        #expect(await store.markerOwner(districtId: legacyRoute.districtId, periodId: legacyRoute.periodId) == legacyRoute.id)
        #expect(await store.route(id: legacyRoute.id) == legacyRoute)
    }

    @Test
    func legacy重複はどちらかを更新しても隠れず409にする() async throws {
        let store = RouteMemoryDataStore()
        let periods = [Period.mock(id: "period-a", festivalId: "festival-1")]
        let legacyA = Route.mock(id: "legacy-a", districtId: "district-1", periodId: "period-a")
        let legacyB = Route.mock(id: "legacy-b", districtId: "district-1", periodId: "period-a")
        await store.seedLegacy(legacyA)
        await store.seedLegacy(legacyB)

        let update = try await send(.put, path: "/routes/legacy-a", route: legacyA, store: store, periods: periods)
        #expect(update.statusCode == 409)
        #expect(await store.route(id: legacyA.id) == legacyA)
        #expect(await store.route(id: legacyB.id) == legacyB)
        #expect(await store.markerOwner(districtId: legacyA.districtId, periodId: legacyA.periodId) == nil)
    }

    @Test
    func repository地区変更で旧markerを消し新markerを設定する() async throws {
        let store = RouteMemoryDataStore()
        let oldRoute = Route.mock(id: "route-move", districtId: "district-old", periodId: "period-old")
        let newRoute = Route.mock(id: oldRoute.id, districtId: "district-new", periodId: "period-new")
        let period = Period.mock(id: newRoute.periodId, festivalId: "festival-1")
        let districts = [
            District.mock(id: oldRoute.districtId, festivalId: "festival-1"),
            District.mock(id: newRoute.districtId, festivalId: "festival-1")
        ]
        await store.seedLegacy(oldRoute)

        try await withDependencies {
            $0[DataStoreFactoryKey.self] = { _ in store }
            $0[PeriodRepositoryKey.self] = PeriodRepositoryMock(getHandler: { _ in period })
            $0[DistrictRepositoryKey.self] = DistrictRepositoryMock(queryHandler: { _ in districts })
        } operation: {
            let repository = RouteRepository()
            _ = try await repository.put(newRoute, replacing: oldRoute)
        }

        #expect(await store.route(id: oldRoute.id) == newRoute)
        #expect(await store.markerOwner(districtId: oldRoute.districtId, periodId: oldRoute.periodId) == nil)
        #expect(await store.markerOwner(districtId: newRoute.districtId, periodId: newRoute.periodId) == newRoute.id)
    }

    @Test
    func legacy重複Routeを削除すると別Routeのmarkerを維持する() async throws {
        let store = RouteMemoryDataStore()
        let routeA = Route.mock(id: "legacy-a", districtId: "district-1", periodId: "period-a")
        let routeB = Route.mock(id: "legacy-b", districtId: "district-1", periodId: "period-a")
        await store.seedLegacy(routeA)
        await store.seedLegacy(routeB)
        await store.seedMarker(for: routeB)

        try await withDependencies {
            $0[DataStoreFactoryKey.self] = { _ in store }
        } operation: {
            let repository = RouteRepository()
            try await repository.delete(routeA)
        }

        #expect(await store.route(id: routeA.id) == nil)
        #expect(await store.route(id: routeB.id) == routeB)
        #expect(await store.markerOwner(districtId: routeB.districtId, periodId: routeB.periodId) == routeB.id)
    }
}
