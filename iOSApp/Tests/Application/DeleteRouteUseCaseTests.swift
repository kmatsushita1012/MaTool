import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct DeleteRouteUseCaseTests {
    @Test("削除成功後は指定ルートを消し、選択中であれば解除する")
    func removesSelectedRouteAfterSuccess() async throws {
        let first = AppStateFixture.route()
        let second = AppStateFixture.route(id: "remaining")
        let state = Shared<AppState?>(value: AppStateFixture.state(
            routes: [first, second], currentRouteId: first.id
        ))
        let spy = RouteDataFetcherSpy(pack: RoutePack(route: first, points: [], passages: []))
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = spy
        } operation: { DeleteRouteUseCase() }

        try await useCase(routeId: first.id, appState: state)

        #expect(state.wrappedValue?.districtState?.routes.map(\.id) == ["remaining"])
        #expect(state.wrappedValue?.routeState == nil)
        #expect(await spy.recordedCalls() == ["delete:route"])
    }

    @Test("非選択ルートの削除では選択ルートは残す")
    func deletingOtherRouteRetainsSelection() async throws {
        let first = AppStateFixture.route()
        let second = AppStateFixture.route(id: "other")
        let state = Shared<AppState?>(value: AppStateFixture.state(
            routes: [first, second], currentRouteId: first.id
        ))
        let spy = RouteDataFetcherSpy(pack: RoutePack(route: first, points: [], passages: []))
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = spy
        } operation: { DeleteRouteUseCase() }

        try await useCase(routeId: second.id, appState: state)

        #expect(state.wrappedValue?.districtState?.routes.map(\.id) == ["route"])
        #expect(state.wrappedValue?.routeState?.route.id == "route")
    }

    @Test("APIが失敗したらローカルルートを残す")
    func errorLeavesRoutesIntact() async {
        let route = AppStateFixture.route()
        let original = AppStateFixture.state(
            routes: [route], currentRouteId: route.id
        )
        let state = Shared<AppState?>(value: original)
        let spy = RouteDataFetcherSpy(
            pack: RoutePack(route: route, points: [], passages: []),
            shouldFail: true
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = spy
        } operation: { DeleteRouteUseCase() }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(routeId: route.id, appState: state)
        }
        #expect(state.wrappedValue == original)
    }

    @Test("画面状態が存在しないときでもリモートの削除は行う")
    func nilStateStillDeletesRemotely() async throws {
        let route = AppStateFixture.route()
        let spy = RouteDataFetcherSpy(pack: RoutePack(route: route, points: [], passages: []))
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = spy
        } operation: { DeleteRouteUseCase() }
        let state = Shared<AppState?>(value: nil)

        try await useCase(routeId: "route", appState: state)

        #expect(state.wrappedValue == nil)
        #expect(await spy.recordedCalls() == ["delete:route"])
    }
}
