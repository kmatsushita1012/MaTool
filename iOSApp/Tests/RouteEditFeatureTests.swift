import ComposableArchitecture
import Dependencies
import SQLiteData
import Shared
import Testing
@testable import iOSApp

struct RouteEditFeatureTests {
    @Test("新規作成中の複製は新しいRoute IDと外部キーでcreateする") @MainActor
    func 新規作成中の複製は新しいIDでcreateする() async throws {
        let fixture = try await makeRouteCopyFixture(mode: .create)
        let store = TestStore(initialState: fixture.initialState) {
            RouteEditFeature()
        } withDependencies: {
            $0.defaultDatabase = fixture.database
            $0[CheckpointStoreKey.self] = SQLiteStore<Checkpoint>()
            $0[RouteDataFetcherKey.self] = fixture.dataFetcher
        }
        store.exhaustivity = .off

        await selectSourceRoute(in: store, fixture: fixture)

        let copiedState = store.state
        #expect(copiedState.mode == .create)
        #expect(copiedState.route.id != fixture.sourceRoute.id)
        #expect(copiedState.route.id != fixture.destinationRoute.id)
        #expect(copiedState.route.districtId == fixture.destinationRoute.districtId)
        #expect(copiedState.route.periodId == fixture.destinationRoute.periodId)
        #expect(copiedState.route.visibility == fixture.sourceRoute.visibility)
        #expect(copiedState.route.description == fixture.sourceRoute.description)
        expectCopiedChildren(copiedState, fixture: fixture)

        await store.send(.saveTapped)
        await store.receive(.saveReceived(.success))

        let submission = await fixture.dataFetcher.createdSubmission()
        #expect(submission?.routeID == copiedState.route.id)
        #expect(submission?.districtID == fixture.destinationRoute.districtId)
        #expect(submission?.periodID == fixture.destinationRoute.periodId)
        #expect(submission?.points.allSatisfy { $0.routeID == copiedState.route.id } == true)
        #expect(submission?.passages.allSatisfy { $0.routeID == copiedState.route.id } == true)
        #expect(await fixture.dataFetcher.updatedSubmission() == nil)
        await store.finish()
    }

    @Test("編集中の複製は編集先Route IDと外部キーを維持してupdateする") @MainActor
    func 編集中の複製は編集先IDと外部キーでupdateする() async throws {
        let fixture = try await makeRouteCopyFixture(mode: .update)
        let store = TestStore(initialState: fixture.initialState) {
            RouteEditFeature()
        } withDependencies: {
            $0.defaultDatabase = fixture.database
            $0[CheckpointStoreKey.self] = SQLiteStore<Checkpoint>()
            $0[RouteDataFetcherKey.self] = fixture.dataFetcher
        }
        store.exhaustivity = .off

        await selectSourceRoute(in: store, fixture: fixture)

        let copiedState = store.state
        #expect(copiedState.mode == .update)
        #expect(copiedState.route.id == fixture.destinationRoute.id)
        #expect(copiedState.route.districtId == fixture.destinationRoute.districtId)
        #expect(copiedState.route.periodId == fixture.destinationRoute.periodId)
        #expect(copiedState.route.visibility == fixture.sourceRoute.visibility)
        #expect(copiedState.route.description == fixture.sourceRoute.description)
        expectCopiedChildren(copiedState, fixture: fixture)

        await store.send(.saveTapped)
        await store.receive(.saveReceived(.success))

        let submission = await fixture.dataFetcher.updatedSubmission()
        #expect(submission?.routeID == fixture.destinationRoute.id)
        #expect(submission?.districtID == fixture.destinationRoute.districtId)
        #expect(submission?.periodID == fixture.destinationRoute.periodId)
        #expect(submission?.points.allSatisfy { $0.routeID == fixture.destinationRoute.id } == true)
        #expect(submission?.passages.allSatisfy { $0.routeID == fixture.destinationRoute.id } == true)
        #expect(await fixture.dataFetcher.createdSubmission() == nil)
        await store.finish()
    }
}

@MainActor
private func selectSourceRoute(
    in store: TestStore<RouteEditFeature.State, RouteEditFeature.Action>,
    fixture: RouteCopyFixture
) async {
    await store.send(.sourceSelected(RouteEntry(period: fixture.sourcePeriod, route: fixture.sourceRoute)))
    await store.receive(.copyPrepared(.success(fixture.sourceRoute.id)))
}

@MainActor
private func expectCopiedChildren(_ state: RouteEditFeature.State, fixture: RouteCopyFixture) {
    let sourcePointIDs = Set(fixture.sourcePoints.map(\.id))
    #expect(state.points.count == fixture.sourcePoints.count)
    #expect(state.points.allSatisfy { $0.routeId == state.route.id })
    #expect(state.points.allSatisfy { !sourcePointIDs.contains($0.id) })
    #expect(state.points.map(\.coordinate) == fixture.sourcePoints.map(\.coordinate))
    #expect(state.points.map(\.checkpointId) == fixture.sourcePoints.map(\.checkpointId))
    #expect(state.points.map(\.performanceId) == fixture.sourcePoints.map(\.performanceId))
    #expect(state.points.map(\.isBoundary) == fixture.sourcePoints.map(\.isBoundary))

    let sourcePassageIDs = Set(fixture.sourcePassages.map(\.id))
    #expect(state.passages.count == fixture.sourcePassages.count)
    #expect(state.passages.allSatisfy { $0.routeId == state.route.id })
    #expect(state.passages.allSatisfy { !sourcePassageIDs.contains($0.id) })
    #expect(state.passages.map(\.districtId) == fixture.sourcePassages.map(\.districtId))
    #expect(state.passages.map(\.memo) == fixture.sourcePassages.map(\.memo))
    #expect(state.passages.map(\.order) == fixture.sourcePassages.map(\.order))
}

@MainActor
private func makeRouteCopyFixture(mode: RouteEditFeature.EditMode) async throws -> RouteCopyFixture {
    let database = try DatabaseQueue(path: ":memory:")
    try makeDatabaseMigrator().migrate(database)

    let festival = Festival(
        id: "festival",
        name: "Festival",
        subname: "Festival",
        base: Coordinate(latitude: 35, longitude: 139)
    )
    let district = District(id: "destination-district", name: "Destination District", festivalId: festival.id)
    let sourceDistrict = District(id: "source-district", name: "Source District", festivalId: festival.id)
    let passageDistrict = District(id: "passage-district", name: "Passage District", festivalId: festival.id)
    let sourcePeriod = Period(
        id: "source-period",
        festivalId: festival.id,
        title: "Source period",
        date: SimpleDate(year: 2025, month: 10, day: 3),
        start: SimpleTime(hour: 9, minute: 0),
        end: SimpleTime(hour: 17, minute: 0)
    )
    let destinationPeriod = Period(
        id: "destination-period",
        festivalId: festival.id,
        title: "Destination period",
        date: SimpleDate(year: 2026, month: 10, day: 3),
        start: SimpleTime(hour: 9, minute: 0),
        end: SimpleTime(hour: 17, minute: 0)
    )
    let sourceRoute = Route(
        id: "source-route",
        districtId: sourceDistrict.id,
        periodId: sourcePeriod.id,
        visibility: .route,
        description: "copied description"
    )
    let destinationRoute = Route(
        id: mode == .create ? "new-draft-route" : "destination-route",
        districtId: district.id,
        periodId: destinationPeriod.id,
        visibility: .admin,
        description: "destination description"
    )
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
            id: "source-checkpoint",
            routeId: sourceRoute.id,
            coordinate: Coordinate(latitude: 35.05, longitude: 139.05),
            time: SimpleTime(hour: 9, minute: 15),
            checkpointId: "source-checkpoint-ref",
            index: 1,
            isBoundary: true
        ),
        Point(
            id: "source-performance",
            routeId: sourceRoute.id,
            coordinate: Coordinate(latitude: 35.075, longitude: 139.075),
            time: SimpleTime(hour: 9, minute: 30),
            performanceId: "source-performance-ref",
            index: 2
        ),
        Point(
            id: "source-end",
            routeId: sourceRoute.id,
            coordinate: Coordinate(latitude: 35.1, longitude: 139.1),
            time: SimpleTime(hour: 10, minute: 0),
            anchor: .end,
            index: 3
        )
    ]
    let sourcePassages = [
        RoutePassage(
            id: "source-passage",
            routeId: sourceRoute.id,
            districtId: passageDistrict.id,
            memo: "copied passage",
            order: 5
        )
    ]
    let dataFetcher = RouteDataFetcherSpy()

    try await database.write { db in
        try FestivalStoreKey.liveValue.upsert(festival, at: db)
        try DistrictStoreKey.liveValue.upsert([district, sourceDistrict, passageDistrict], at: db)
        try PeriodStoreKey.liveValue.upsert([sourcePeriod, destinationPeriod], at: db)
        try RouteStoreKey.liveValue.upsert([sourceRoute, destinationRoute], at: db)
        try PointStoreKey.liveValue.upsert(sourcePoints, at: db)
        try PassageStoreKey.liveValue.upsert(sourcePassages, at: db)
    }

    let initialState = try withDependencies {
        $0.defaultDatabase = database
        $0[CheckpointStoreKey.self] = SQLiteStore<Checkpoint>()
    } operation: {
        try RouteEditFeature.State(mode: mode, route: destinationRoute)
    }

    return RouteCopyFixture(
        database: database,
        initialState: initialState,
        sourcePeriod: sourcePeriod,
        sourceRoute: sourceRoute,
        destinationRoute: destinationRoute,
        sourcePoints: sourcePoints,
        sourcePassages: sourcePassages,
        dataFetcher: dataFetcher
    )
}

private struct RouteCopyFixture {
    let database: DatabaseQueue
    let initialState: RouteEditFeature.State
    let sourcePeriod: Period
    let sourceRoute: Route
    let destinationRoute: Route
    let sourcePoints: [Point]
    let sourcePassages: [RoutePassage]
    let dataFetcher: RouteDataFetcherSpy
}

private struct RouteSubmission: Equatable, Sendable {
    let routeID: String
    let districtID: String
    let periodID: String
    let points: [PointSubmission]
    let passages: [PassageSubmission]

    init(route: Route, points: [Point], passages: [RoutePassage]) {
        self.routeID = route.id
        self.districtID = route.districtId
        self.periodID = route.periodId
        self.points = points.map(PointSubmission.init)
        self.passages = passages.map(PassageSubmission.init)
    }
}

private struct PointSubmission: Equatable, Sendable {
    let id: String
    let routeID: String
    let checkpointID: String?
    let performanceID: String?

    init(_ point: Point) {
        self.id = point.id
        self.routeID = point.routeId
        self.checkpointID = point.checkpointId
        self.performanceID = point.performanceId
    }
}

private struct PassageSubmission: Equatable, Sendable {
    let id: String
    let routeID: String
    let districtID: String?

    init(_ passage: RoutePassage) {
        self.id = passage.id
        self.routeID = passage.routeId
        self.districtID = passage.districtId
    }
}

private actor RouteDataFetcherSpy: RouteDataFetcherProtocol {
    private var created: RouteSubmission?
    private var updated: RouteSubmission?

    func fetchAll(districtID: District.ID, query: Query) async throws {}

    func fetch(routeID: Route.ID) async throws {}

    func update(_ route: Route, points: [Point], passages: [RoutePassage]) async throws {
        updated = RouteSubmission(route: route, points: points, passages: passages)
    }

    func create(
        districtID: District.ID,
        route: Route,
        points: [Point],
        passages: [RoutePassage]
    ) async throws {
        created = RouteSubmission(route: route, points: points, passages: passages)
    }

    func delete(_ routeID: Route.ID) async throws {}

    func createdSubmission() -> RouteSubmission? { created }

    func updatedSubmission() -> RouteSubmission? { updated }
}
