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
        let dataFetcher = SupersedingRouteDataFetcherSpy(
            appState: fixture.appState,
            response: RoutePack(route: fixture.responseRoute, points: [], passages: [])
        )
        let useCase = withDependencies {
            $0.installTestSpies()
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
        } withDependencies: {
            $0.installTestSpies()
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
        } withDependencies: {
            $0.installTestSpies()
        }
        await detailStore.send(.routeReceived(.success(response))) {
            $0.isLoading = false
        }
        #expect(detailStore.state.destination == nil)
        await detailStore.finish()
    }
    @Test("有効なRoute応答は地区のRouteと選択中のRouteStateに同時反映する")
    @MainActor
    func validRouteResponseUpdatesBothStates() async throws {
        let fixture = RouteLoadingFixture()
        let pack = RoutePack(route: fixture.responseRoute, points: [], passages: [])
        let fetcher = RouteDataFetcherSpy(pack: pack)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = fetcher
        } operation: {
            LoadRouteStateUseCase()
        }

        let result = try await useCase(routeId: fixture.route.id, appState: fixture.appState)

        #expect(result == pack)
        #expect(fixture.appState.wrappedValue?.districtState?.route(id: fixture.route.id)?.description == "stale response")
        #expect(fixture.appState.wrappedValue?.routeState?.route.description == "stale response")
        #expect(await fetcher.recordedCalls() == ["fetch:route"])
    }

    @Test("地区に存在しないRouteの要求はデータ取得を実行せず状態を変更しない")
    @MainActor
    func unknownRouteDoesNotFetch() async throws {
        let fixture = RouteLoadingFixture()
        let pack = RoutePack(route: fixture.responseRoute, points: [], passages: [])
        let fetcher = RouteDataFetcherSpy(pack: pack)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = fetcher
        } operation: {
            LoadRouteStateUseCase()
        }

        let result = try await useCase(routeId: "unknown", appState: fixture.appState)

        #expect(result == nil)
        #expect(fixture.appState.wrappedValue?.routeState?.route.description == "current")
        #expect(await fetcher.recordedCalls().isEmpty)
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
            districtId: district.id
        ))
    }
}
