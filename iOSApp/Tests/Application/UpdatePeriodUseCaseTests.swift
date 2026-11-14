import ComposableArchitecture
import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

struct UpdatePeriodUseCaseTests {
    private func setupState(
        periods: [Period] = [AppStateFixture.period()],
        routes: [Route] = [AppStateFixture.route()],
        currentRoute: String? = "route"
    ) -> Shared<AppState?> {
        Shared(value: AppStateFixture.state(
            periods: periods, routes: routes, currentRouteId: currentRoute
        ))
    }

    @Test("期間の更新成功でサーバー値を使用し、関連ルートを再取得する")
    func refreshesRoutesAfterPeriodUpdate() async throws {
        let old = AppStateFixture.period()
        var normalized = old
        normalized.title = "server version"
        let oldRoute = AppStateFixture.route()
        let newRoute = AppStateFixture.route(id: "afterRefresh")
        let state = setupState(routes: [oldRoute])
        let spy = PeriodDataFetcherSpy(response: normalized)
        let routeSpy = RouteDataFetcherSpy(
            pack: RoutePack(route: newRoute, points: [], passages: []),
            routes: [newRoute]
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = spy
            $0[RouteDataFetcherKey.self] = routeSpy
        } operation: { UpdatePeriodUseCase() }
        let beforeRouteLoadId = state.wrappedValue?.routeLoadRequestId

        let actual = try await useCase(old, appState: state)

        #expect(actual == normalized)
        #expect(state.wrappedValue?.festivalState.periods.map(\.title) == ["server version"])
        #expect(state.wrappedValue?.districtState?.routes == [newRoute])
        #expect(state.wrappedValue?.routeState == nil)
        #expect(state.wrappedValue?.routeLoadRequestId != beforeRouteLoadId)
        #expect(await spy.recordedCalls() == ["update:period"])
        #expect(await routeSpy.recordedCalls() == ["fetchAll:district:year(2026)"])
    }

    @Test("更新された期間が異年度ならルート再読込をしない")
    func otherYearDoesNotRefreshRoutes() async throws {
        let original = AppStateFixture.period()
        let nextYear = Period(
            id: original.id, festivalId: "festival",
            date: SimpleDate(year: 2027, month: 10, day: 3),
            start: original.start, end: original.end
        )
        let route = AppStateFixture.route()
        let state = setupState(routes: [route])
        let routeSpy = RouteDataFetcherSpy(
            pack: RoutePack(route: route, points: [], passages: []),
            shouldFail: true
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = PeriodDataFetcherSpy(response: nextYear)
            $0[RouteDataFetcherKey.self] = routeSpy
        } operation: { UpdatePeriodUseCase() }

        #expect(try await useCase(original, appState: state) == nextYear)
        #expect(await routeSpy.recordedCalls().isEmpty)
        #expect(state.wrappedValue?.festivalState.periods == [nextYear])
    }

    @Test("期間PUT成功後のルート再読込失敗は期間保存を失敗扱いにしない")
    func refreshErrorDoesNotUndoPeriodSave() async throws {
        let old = AppStateFixture.period()
        var response = old
        response.title = "saved"
        let route = AppStateFixture.route()
        let state = setupState(routes: [route])
        let routeSpy = RouteDataFetcherSpy(
            pack: RoutePack(route: route, points: [], passages: []),
            shouldFail: true
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = PeriodDataFetcherSpy(response: response)
            $0[RouteDataFetcherKey.self] = routeSpy
        } operation: { UpdatePeriodUseCase() }

        #expect(try await useCase(old, appState: state) == response)
        #expect(state.wrappedValue?.festivalState.periods.first?.title == "saved")
        #expect(state.wrappedValue?.districtState?.routes == [route])
        #expect(await routeSpy.recordedCalls().count == 1)
    }

    @Test("再読込がキャンセルされたら期間PUT成功後でもCancellationErrorを投げる")
    func propagatesCancellation() async {
        let period = AppStateFixture.period()
        let route = AppStateFixture.route()
        let state = setupState(routes: [route])
        let routeSpy = RouteDataFetcherSpy(
            pack: RoutePack(route: route, points: [], passages: []),
            cancellationOnFetchAll: true
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = PeriodDataFetcherSpy(response: period)
            $0[RouteDataFetcherKey.self] = routeSpy
        } operation: { UpdatePeriodUseCase() }

        await #expect(throws: CancellationError.self) {
            try await useCase(period, appState: state)
        }
        #expect(await routeSpy.recordedCalls().count == 1)
    }

    @Test("期間PUT自体が失敗した場合はローカル状態もルートも変えない")
    func periodUpdateFailurePreservesState() async {
        let period = AppStateFixture.period()
        let original = AppStateFixture.state(routes: [AppStateFixture.route()])
        let state = Shared<AppState?>(value: original)
        let spy = PeriodDataFetcherSpy(response: period, shouldFail: true)
        let route = AppStateFixture.route()
        let routeSpy = RouteDataFetcherSpy(
            pack: RoutePack(route: route, points: [], passages: []),
            shouldFail: true
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = spy
            $0[RouteDataFetcherKey.self] = routeSpy
        } operation: { UpdatePeriodUseCase() }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(period, appState: state)
        }
        #expect(state.wrappedValue == original)
        #expect(await routeSpy.recordedCalls().isEmpty)
    }

    @Test("地区状態が存在しない場合は期間だけ更新してルート取得をスキップする")
    func noDistrictSkipsRouteRefresh() async throws {
        let period = AppStateFixture.period()
        var returned = period
        returned.title = "saved"
        let state = Shared<AppState?>(value: AppStateFixture.state(selectedDistrictId: nil))
        let route = AppStateFixture.route()
        let routeSpy = RouteDataFetcherSpy(
            pack: RoutePack(route: route, points: [], passages: []),
            shouldFail: true
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = PeriodDataFetcherSpy(response: returned)
            $0[RouteDataFetcherKey.self] = routeSpy
        } operation: { UpdatePeriodUseCase() }

        #expect(try await useCase(period, appState: state) == returned)
        #expect(state.wrappedValue?.festivalState.periods.first?.title == "saved")
        #expect(await routeSpy.recordedCalls().isEmpty)
    }
}
