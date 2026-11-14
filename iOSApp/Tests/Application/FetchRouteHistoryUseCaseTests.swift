import Dependencies
import Shared
import Testing
@testable import iOSApp

struct FetchRouteHistoryUseCaseTests {
    @Test("期間に紐づく経路だけを返し、日時と経路IDで安定ソートする")
    func resolvesAndSortsRouteEntries() async throws {
        let first = AppStateFixture.period(id: "period1", day: 1)
        let second = AppStateFixture.period(id: "period2", day: 3)
        let firstB = AppStateFixture.route(id: "b", periodId: first.id)
        let firstA = AppStateFixture.route(id: "a", periodId: first.id)
        let secondRoute = AppStateFixture.route(id: "later", periodId: second.id)
        let orphan = AppStateFixture.route(id: "orphan", periodId: "unknown")
        let periodSpy = PeriodDataFetcherSpy(response: first, list: [second, first])
        let routeSpy = RouteDataFetcherSpy(
            pack: RoutePack(route: firstA, points: [], passages: []),
            routes: [secondRoute, orphan, firstB, firstA]
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = periodSpy
            $0[RouteDataFetcherKey.self] = routeSpy
        } operation: { FetchRouteHistoryUseCase() }

        let result = try await useCase(districtId: "district", festivalId: "festival")

        #expect(result.map(\.route.id) == ["a", "b", "later"])
        #expect(await periodSpy.recordedCalls() == ["fetchAll:festival:all"])
        #expect(await routeSpy.recordedCalls() == ["fetchAll:district:all"])
    }

    @Test("すべての経路が存在しない期間を参照する場合は空を返す")
    func orphanRoutesAreExcluded() async throws {
        let period = AppStateFixture.period()
        let route = AppStateFixture.route(periodId: "missing")
        let periodSpy = PeriodDataFetcherSpy(response: period, list: [period])
        let routeSpy = RouteDataFetcherSpy(
            pack: RoutePack(route: route, points: [], passages: []), routes: [route]
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = periodSpy
            $0[RouteDataFetcherKey.self] = routeSpy
        } operation: { FetchRouteHistoryUseCase() }

        #expect(try await useCase(districtId: "district", festivalId: "festival").isEmpty)
    }

    @Test("どちらかの取得に失敗した場合は部分結果を返さない")
    func propagatesPartialFailure() async {
        let period = AppStateFixture.period()
        let route = AppStateFixture.route()
        let periodSpy = PeriodDataFetcherSpy(response: period, shouldFail: true)
        let routeSpy = RouteDataFetcherSpy(
            pack: RoutePack(route: route, points: [], passages: []), routes: [route]
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = periodSpy
            $0[RouteDataFetcherKey.self] = routeSpy
        } operation: { FetchRouteHistoryUseCase() }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(districtId: "district", festivalId: "festival")
        }
    }
}
