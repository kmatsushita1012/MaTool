import Dependencies
import Shared
import Testing
@testable import iOSApp

struct FetchRouteHistoryUseCaseTests {
    @Test("対象地区と年度を指定して履歴を取得する")
    func fetchesHistory() async throws {
        let edition = AppStateFixture.edition(year: 2025)
        let entry = RouteEntry(period: AppStateFixture.period(edition: edition), route: AppStateFixture.route())
        let history = [EditionRouteGroup(edition: edition, entries: [entry])]
        let spy = RouteDataFetcherSpy(pack: RoutePack(route: entry.route, points: [], passages: []), history: history)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = spy
        } operation: { FetchRouteHistoryUseCase() }

        #expect(try await useCase(districtId: "district", editionId: "current") == history)
        #expect(await spy.recordedCalls() == ["history:district:current"])
    }

    @Test("履歴取得のエラーを伝える")
    func propagatesFailure() async {
        let route = AppStateFixture.route()
        let spy = RouteDataFetcherSpy(pack: RoutePack(route: route, points: [], passages: []), shouldFail: true)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = spy
        } operation: { FetchRouteHistoryUseCase() }
        await #expect(throws: FetcherTestError.failed) {
            try await useCase(districtId: "district", editionId: "current")
        }
    }
}
