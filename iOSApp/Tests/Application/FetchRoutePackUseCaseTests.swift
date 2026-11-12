import Dependencies
import Shared
import Testing
@testable import iOSApp

struct FetchRoutePackUseCaseTests {
    @Test("指定した経路IDのパックを取得する")
    func fetchesFullRoutePack() async throws {
        let route = AppStateFixture.route()
        let point = Point(
            id: "point", routeId: route.id,
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let pack = RoutePack(route: route, points: [point], passages: [])
        let spy = RouteDataFetcherSpy(pack: pack)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = spy
        } operation: { FetchRoutePackUseCase() }

        let response = try await useCase(routeId: route.id)

        #expect(response.route == route)
        #expect(response.points == [point])
        #expect(await spy.recordedCalls() == ["fetch:route"])
    }

    @Test("通信失敗時は空パックを捏造せずエラーを伝える")
    func propagatesFailure() async {
        let route = AppStateFixture.route()
        let spy = RouteDataFetcherSpy(
            pack: RoutePack(route: route, points: [], passages: []),
            shouldFail: true
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = spy
        } operation: { FetchRoutePackUseCase() }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(routeId: "route")
        }
    }
}
