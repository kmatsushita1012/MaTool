import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct CreateRouteUseCaseTests {
    @Test("新規Route作成ではAPIのレスポンスで現在ルートを更新する")
    func usesReturnedRoutePack() async throws {
        let submitted = AppStateFixture.route(id: "temporary")
        let returned = AppStateFixture.route(id: "new-server-id")
        let pack = RoutePack(route: returned, points: [], passages: [])
        let spy = RouteDataFetcherSpy(pack: pack)
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = spy
        } operation: { CreateRouteUseCase() }

        let response = try await useCase(
            districtId: "district", route: submitted,
            points: [], passages: [], appState: state
        )

        #expect(response.route == returned)
        #expect(state.wrappedValue?.districtState?.routes.map(\.id) == ["new-server-id"])
        #expect(state.wrappedValue?.routeState?.route.id == "new-server-id")
        #expect(await spy.recordedCalls() == ["create:district:temporary"])
    }

    @Test("API失敗時はルート一覧と画面選択を維持する")
    func failurePreservesState() async {
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let route = AppStateFixture.route()
        let spy = RouteDataFetcherSpy(
            pack: RoutePack(route: route, points: [], passages: []),
            shouldFail: true
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = spy
        } operation: { CreateRouteUseCase() }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(
                districtId: "district", route: route,
                points: [], passages: [], appState: state
            )
        }
        #expect(state.wrappedValue == original)
    }

    @Test("有効なセッションがない場合でもリモート作成結果は返す")
    func nilSessionAvoidsLocalMutations() async throws {
        let route = AppStateFixture.route()
        let spy = RouteDataFetcherSpy(pack: RoutePack(route: route, points: [], passages: []))
        let state = Shared<AppState?>(value: nil)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = spy
        } operation: { CreateRouteUseCase() }

        let result = try await useCase(
            districtId: "district", route: route,
            points: [], passages: [], appState: state
        )

        #expect(result.route == route)
        #expect(state.wrappedValue == nil)
    }
}
