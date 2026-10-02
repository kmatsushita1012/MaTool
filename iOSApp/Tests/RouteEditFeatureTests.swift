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
        #expect(state.points.allSatisfy { $0.routeId == state.route.id })
        #expect(state.passages.count == 1)
        #expect(state.passages.allSatisfy { $0.routeId == state.route.id })
        #expect(!state.isDeleteable)

        await store.send(.saveTapped)
        await store.receive(.saveReceived(.success))
        #expect(await dataFetcher.createdRouteId() == state.route.id)
        #expect(await dataFetcher.updatedRouteId() == nil)
        await store.finish()
    }
}

private actor RouteDataFetcherSpy: RouteDataFetcherProtocol {
    private var createdId: Route.ID?
    private var updatedId: Route.ID?

    func fetchAll(districtID: District.ID, query: Query) async throws {}

    func fetch(routeID: Route.ID) async throws {}

    func update(_ route: Route, points: [Point], passages: [RoutePassage]) async throws {
        updatedId = route.id
    }

    func create(
        districtID: District.ID,
        route: Route,
        points: [Point],
        passages: [RoutePassage]
    ) async throws {
        createdId = route.id
    }

    func delete(_ routeID: Route.ID) async throws {}

    func createdRouteId() -> Route.ID? { createdId }

    func updatedRouteId() -> Route.ID? { updatedId }
}
