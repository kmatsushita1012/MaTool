import Dependencies
import Shared
import Testing
@testable import iOSApp

struct FetchRouteUseCaseTests {
    @Test("地区IDと年度をDataFetcherに渡し、返された経路を維持する")
    func delegatesRouteLookup() async throws {
        let route = AppStateFixture.route()
        let spy = RouteDataFetcherSpy(
            pack: RoutePack(route: route, points: [], passages: []),
            routes: [route]
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = spy
        } operation: {
            FetchRouteUseCase()
        }

        let routes = try await useCase(districtId: "district", query: .year(2026))

        #expect(routes == [route])
        #expect(await spy.recordedCalls() == ["fetchAll:district:year(2026)"])
    }

    @Test("経路が存在しない場合は空の一覧を返す")
    func emptyResultsStayEmpty() async throws {
        let route = AppStateFixture.route()
        let spy = RouteDataFetcherSpy(pack: RoutePack(route: route, points: [], passages: []))
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = spy
        } operation: { FetchRouteUseCase() }

        #expect(try await useCase(districtId: "district", query: .latest).isEmpty)
    }

    @Test("取得失敗時はエラーを通知する")
    func propagatesFailure() async {
        let route = AppStateFixture.route()
        let spy = RouteDataFetcherSpy(
            pack: RoutePack(route: route, points: [], passages: []),
            shouldFail: true
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = spy
        } operation: { FetchRouteUseCase() }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(districtId: "district", query: .all)
        }
    }
}
