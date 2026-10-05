import ComposableArchitecture
import Dependencies
import SQLiteData
import Shared
import Testing
@testable import iOSApp

struct RouteEditFeatureTests {
    @Test("ルート複製後は新規作成モードで保存する") @MainActor
    func ルート複製後は新規作成モードになる() async throws {
        let database = try DatabaseQueue(path: ":memory:")
        try makeDatabaseMigrator().migrate(database)

        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let district = District(id: "district", name: "District", festivalId: festival.id)
        let period = Period(
            id: "period",
            festivalId: festival.id,
            date: SimpleDate(year: 2026, month: 10, day: 3),
            start: SimpleTime(hour: 9, minute: 0),
            end: SimpleTime(hour: 17, minute: 0)
        )
        let sourceRoute = Route(id: "source-route", districtId: district.id, periodId: period.id)
        let sourcePoints = [
            Point(
                id: "source-start",
                routeId: sourceRoute.id,
                coordinate: Coordinate(latitude: 35, longitude: 139),
                time: SimpleTime(hour: 9, minute: 0),
                anchor: .start,
                index: 0
            ),
            Point(
                id: "source-end",
                routeId: sourceRoute.id,
                coordinate: Coordinate(latitude: 35.1, longitude: 139.1),
                time: SimpleTime(hour: 10, minute: 0),
                anchor: .end,
                index: 1
            )
        ]
        let sourcePassage = RoutePassage(
            id: "source-passage",
            routeId: sourceRoute.id,
            districtId: district.id
        )
        let dataFetcher = RouteDataFetcherSpy()

        try await database.write { db in
            try FestivalStoreKey.liveValue.upsert(festival, at: db)
            try DistrictStoreKey.liveValue.upsert(district, at: db)
            try PeriodStoreKey.liveValue.upsert(period, at: db)
            try RouteStoreKey.liveValue.upsert(sourceRoute, at: db)
            try PointStoreKey.liveValue.upsert(sourcePoints, at: db)
            try PassageStoreKey.liveValue.upsert(sourcePassage, at: db)
        }

        let initialState = try withDependencies {
            $0.defaultDatabase = database
        } operation: {
            try RouteEditFeature.State(
                mode: .update,
                route: Route(id: "edited-route", districtId: district.id, periodId: period.id)
            )
        }
        let store = TestStore(initialState: initialState) {
            RouteEditFeature()
        } withDependencies: {
            $0.defaultDatabase = database
            $0[RouteDataFetcherKey.self] = dataFetcher
        }
        store.exhaustivity = .off

        await store.send(.sourceSelected(RouteEntry(period: period, route: sourceRoute)))
        await store.receive(.copyPrepared(.success(sourceRoute.id)))
        let state = store.state

        #expect(state.mode == .create)
        #expect(state.route.id != sourceRoute.id)
        #expect(state.route.id != "edited-route")
        #expect(state.points.count == sourcePoints.count)
        #expect(state.points.map(\.index) == [0, 1])
        #expect(state.points.allSatisfy { $0.routeId == state.route.id })
        #expect(state.passages.count == 1)
        #expect(state.passages.allSatisfy { $0.routeId == state.route.id })
        #expect(!state.isDeleteable)

        await store.send(.pointTapped(PointEntry(state.points[0])))
        await store.send(.point(.presented(.insertAfterTapped)))
        await store.send(.mapLongPressed(Coordinate(latitude: 35.05, longitude: 139.05)))
        #expect(store.state.points.map(\.index) == [0, 1, 2])

        await store.send(.saveTapped)
        await store.receive(.saveReceived(.success))
        #expect(await dataFetcher.createdRouteId() == state.route.id)
        #expect(await dataFetcher.createdPointIndexes() == [0, 1, 2])
        #expect(await dataFetcher.updatedRouteId() == nil)
        await store.finish()
    }

    @Test("DistrictDashboardから開いた既存ルートで既存Pointに時刻を設定して保存する") @MainActor
    func 既存ルートの既存Pointに時刻を設定して保存する() async throws {
        let database = try DatabaseQueue(path: ":memory:")
        try makeDatabaseMigrator().migrate(database)

        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let district = District(id: "district", name: "District", festivalId: festival.id)
        let performance = Performance(id: "performance", districtId: district.id)
        let period = Period(
            id: "period",
            festivalId: festival.id,
            date: SimpleDate(year: 2026, month: 10, day: 3),
            start: SimpleTime(hour: 9, minute: 0),
            end: SimpleTime(hour: 17, minute: 0)
        )
        let route = Route(id: "route", districtId: district.id, periodId: period.id)
        let points = [
            Point(
                id: "start",
                routeId: route.id,
                coordinate: Coordinate(latitude: 35, longitude: 139),
                time: SimpleTime(hour: 9, minute: 0),
                anchor: .start,
                index: 0
            ),
            Point(
                id: "existing-performance",
                routeId: route.id,
                coordinate: Coordinate(latitude: 35.01, longitude: 139.01),
                performanceId: performance.id,
                index: 3
            ),
            Point(
                id: "timed-performance",
                routeId: route.id,
                coordinate: Coordinate(latitude: 35.015, longitude: 139.015),
                time: SimpleTime(hour: 11, minute: 0),
                performanceId: performance.id,
                index: 3
            ),
            Point(
                id: "end",
                routeId: route.id,
                coordinate: Coordinate(latitude: 35.03, longitude: 139.03),
                time: SimpleTime(hour: 12, minute: 0),
                anchor: .end,
                index: 8
            )
        ]

        try await database.write { db in
            try FestivalStoreKey.liveValue.upsert(festival, at: db)
            try DistrictStoreKey.liveValue.upsert(district, at: db)
            try PerformanceStoreKey.liveValue.upsert(performance, at: db)
            try PeriodStoreKey.liveValue.upsert(period, at: db)
            try RouteStoreKey.liveValue.upsert(route, at: db)
            try PointStoreKey.liveValue.upsert(points, at: db)
        }

        let initialState = try withDependencies {
            $0.defaultDatabase = database
        } operation: {
            try RouteEditFeature.State(
                mode: .update,
                route: route
            )
        }
        let fetchedPointIDs = withDependencies {
            $0.defaultDatabase = database
        } operation: {
            let fetchedPoints: [Point] = FetchAll(routeId: route.id).wrappedValue
            return fetchedPoints.map(\.id)
        }
        #expect(initialState.points.map(\.id) == fetchedPointIDs)
        #expect(initialState.points.map(\.index) == Array(points.indices))
        let editedPointIndex = try #require(initialState.points.firstIndex { $0.id == "existing-performance" })
        let timedPointIndex = try #require(initialState.points.firstIndex { $0.id == "timed-performance" })
        let editedTime = editedPointIndex < timedPointIndex
            ? SimpleTime(hour: 10, minute: 30)
            : SimpleTime(hour: 11, minute: 30)

        let dataFetcher = RouteDataFetcherSpy()
        let store = TestStore(initialState: initialState) {
            RouteEditFeature()
        } withDependencies: {
            $0.defaultDatabase = database
            $0[RouteDataFetcherKey.self] = dataFetcher
        }
        store.exhaustivity = .off

        let pointEntry = withDependencies {
            $0.defaultDatabase = database
        } operation: {
            PointEntry(store.state.points[editedPointIndex])
        }
        await store.send(.pointTapped(pointEntry))
        await store.send(.point(.presented(.binding(.set(
            \.point.time,
            .some(editedTime)
        )))))
        await store.send(.point(.presented(.doneTapped)))

        #expect(store.state.points.map(\.id) == fetchedPointIDs)
        #expect(store.state.points[editedPointIndex].time == editedTime)
        #expect(throws: Never.self) { try store.state.points.validate() }

        await store.send(.saveTapped)
        await store.receive(.saveReceived(.success))
        #expect(await dataFetcher.updatedRouteId() == route.id)
        #expect(await dataFetcher.updatedPointIndexes() == Array(points.indices))
        await store.finish()

    }
}

private actor RouteDataFetcherSpy: RouteDataFetcherProtocol {
    private var createdId: Route.ID?
    private var createdPointIndexValues: [Int]?
    private var updatedId: Route.ID?
    private var updatedPointIndexValues: [Int]?

    func fetchAll(districtID: District.ID, query: Query) async throws {}

    func fetch(routeID: Route.ID) async throws {}

    func update(_ route: Route, points: [Point], passages: [RoutePassage]) async throws {
        updatedId = route.id
        updatedPointIndexValues = points.map(\.index)
    }

    func create(
        districtID: District.ID,
        route: Route,
        points: [Point],
        passages: [RoutePassage]
    ) async throws {
        createdId = route.id
        createdPointIndexValues = points.map(\.index)
    }

    func delete(_ routeID: Route.ID) async throws {}

    func createdRouteId() -> Route.ID? { createdId }

    func createdPointIndexes() -> [Int]? { createdPointIndexValues }

    func updatedRouteId() -> Route.ID? { updatedId }

    func updatedPointIndexes() -> [Int]? { updatedPointIndexValues }
}
