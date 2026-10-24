import Foundation
import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct LoadRouteStateUseCaseTests {
    @Test("取得中に新しいRoute要求が始まった場合、古い結果をAppStateと画面へ反映しない")
    @MainActor
    func staleRouteResponseIsIgnored() async throws {
        let fixture = RouteLoadingFixture()
        let dataFetcher = SupersedingRouteDataFetcher(
            appState: fixture.appState,
            response: RoutePack(route: fixture.responseRoute, points: [], passages: [])
        )
        let useCase = withDependencies {
            $0[RouteDataFetcherKey.self] = dataFetcher
        } operation: {
            LoadRouteStateUseCase()
        }

        var dashboardInitialState = DistrictDashboardFeature.State(
            fixture.district,
            appState: fixture.appState
        )
        dashboardInitialState.isRouteLoading = true
        let dashboardStore = TestStore(initialState: dashboardInitialState) {
            DistrictDashboardFeature()
        }

        let response = try await useCase(routeId: fixture.route.id, appState: fixture.appState)

        #expect(response == nil)
        #expect(fixture.appState.wrappedValue?.routeState?.route.description == "current")
        #expect(fixture.appState.wrappedValue?.districtState?.routes.first?.description == "current")

        await dashboardStore.send(.routeEditReceived(.success(response))) {
            $0.isRouteLoading = false
        }
        #expect(dashboardStore.state.destination == nil)
        await dashboardStore.finish()

        var detailInitialState = HeadquarterDistrictDetailFeature.State(
            fixture.district,
            appState: fixture.appState
        )
        detailInitialState.isLoading = true
        let detailStore = TestStore(initialState: detailInitialState) {
            HeadquarterDistrictDetailFeature()
        }
        await detailStore.send(.routeReceived(.success(response))) {
            $0.isLoading = false
        }
        #expect(detailStore.state.destination == nil)
        await detailStore.finish()
    }
}

private struct RouteLoadingFixture {
    let district: District
    let route: Route
    let responseRoute: Route
    let appState: Shared<AppState?>

    init() {
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
        let route = Route(
            id: "route",
            districtId: district.id,
            periodId: period.id,
            visibility: .admin,
            description: "current"
        )
        var responseRoute = route
        responseRoute.description = "stale response"
        self.district = district
        self.route = route
        self.responseRoute = responseRoute
        appState = Shared(value: AppState(
            festivalPack: LaunchFestivalPack(
                festival: festival,
                districts: [district],
                periods: [period],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
            districtPack: LaunchDistrictPack(
                performances: [],
                routes: [route],
                points: [],
                passages: [],
                currentRouteId: route.id
            ),
            districtId: district.id,
            year: 2026
        ))
    }
}

private struct SupersedingRouteDataFetcher: RouteDataFetcherProtocol {
    let appState: Shared<AppState?>
    let response: RoutePack

    func fetchAll(districtID: District.ID, query: Query) async throws -> [Route] {
        throw CancellationError()
    }

    func fetch(routeID: Route.ID) async throws -> RoutePack {
        appState.withLock { current in
            guard var updated = current else { return }
            updated.routeLoadRequestId = UUID()
            current = updated
        }
        return response
    }

    func update(_ route: Route, points: [Point], passages: [RoutePassage]) async throws -> RoutePack {
        throw CancellationError()
    }

    func create(districtID: District.ID, route: Route, points: [Point], passages: [RoutePassage]) async throws -> RoutePack {
        throw CancellationError()
    }

    func delete(_ routeID: Route.ID) async throws {
        throw CancellationError()
    }
}
