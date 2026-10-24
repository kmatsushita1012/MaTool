import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct RouteEditFeatureTests {
    @Test("過去のRouteをコピーすると別IDの新規RouteとPoint、Passageになる")
    @MainActor
    func 過去Routeのコピーで新しいEntityを作る() async throws {
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let district = District(id: "district", name: "District", festivalId: festival.id)
        let currentPeriod = Period(
            id: "current-period",
            festivalId: festival.id,
            date: SimpleDate(year: 2026, month: 10, day: 3),
            start: SimpleTime(hour: 9, minute: 0),
            end: SimpleTime(hour: 17, minute: 0)
        )
        let pastPeriod = Period(
            id: "past-period",
            festivalId: festival.id,
            date: SimpleDate(year: 2025, month: 10, day: 4),
            start: SimpleTime(hour: 9, minute: 0),
            end: SimpleTime(hour: 17, minute: 0)
        )
        let sourceRoute = Route(
            id: "source-route",
            districtId: district.id,
            periodId: pastPeriod.id,
            visibility: .admin,
            description: "source description"
        )
        let sourcePack = RoutePack(
            route: sourceRoute,
            points: [
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
            ],
            passages: [
                RoutePassage(id: "source-passage", routeId: sourceRoute.id, districtId: district.id, order: 0)
            ]
        )
        let editedRoute = Route(id: "edited-route", districtId: district.id, periodId: currentPeriod.id)
        let festivalState = FestivalState(
            LaunchFestivalPack(
                festival: festival,
                districts: [district],
                periods: [currentPeriod],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
            year: 2026
        )
        let districtState = DistrictState(
            districtId: district.id,
            pack: LaunchDistrictPack(
                performances: [],
                routes: [editedRoute],
                points: [],
                passages: [],
                currentRouteId: editedRoute.id
            ),
            currentPeriodIds: [currentPeriod.id]
        )
        let appState = Shared<AppState?>(value: AppState(
            festivalState: festivalState,
            districtState: districtState,
            routeState: RouteState(route: editedRoute, points: [], passages: [])
        ))
        let initialState = try RouteEditFeature.State(mode: .update, route: editedRoute, appState: appState)
        let store = TestStore(initialState: initialState) {
            RouteEditFeature()
        } withDependencies: {
            $0[FetchRoutePackUseCaseKey.self] = StaticRoutePackUseCase(pack: sourcePack)
        }
        store.exhaustivity = .off

        await store.send(.sourceSelected(RouteEntry(period: pastPeriod, route: sourceRoute)))
        await store.receive(.copyPrepared(.success(sourcePack)))

        let copiedRoute = store.state.route
        #expect(store.state.mode == .create)
        #expect(copiedRoute.id != editedRoute.id)
        #expect(copiedRoute.id != sourceRoute.id)
        #expect(copiedRoute.districtId == district.id)
        #expect(copiedRoute.periodId == currentPeriod.id)
        #expect(copiedRoute.visibility == sourceRoute.visibility)
        #expect(copiedRoute.description == sourceRoute.description)
        #expect(store.state.points.map(\.id).allSatisfy { !sourcePack.points.map(\.id).contains($0) })
        #expect(store.state.points.allSatisfy { $0.routeId == copiedRoute.id })
        #expect(store.state.points.map(\.index) == [0, 1])
        #expect(store.state.passages.map(\.id) != sourcePack.passages.map(\.id))
        #expect(store.state.passages.allSatisfy { $0.routeId == copiedRoute.id })
        await store.finish()
    }
}

private struct StaticRoutePackUseCase: FetchRoutePackUseCaseProtocol {
    let pack: RoutePack

    func callAsFunction(routeId: Route.ID) async throws -> RoutePack {
        pack
    }
}
