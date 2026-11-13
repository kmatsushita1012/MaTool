import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct UpdateRouteUseCaseTests {
    @Test("サーバーから返された経路に更新し、編集済みのPointを保持する")
    func appliesServerRoutePack() async throws {
        let old = AppStateFixture.route(description: "old")
        let edited = AppStateFixture.route(description: "server-edited")
        let point = Point(
            id: "point", routeId: edited.id,
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let pack = RoutePack(route: edited, points: [point], passages: [])
        let spy = RouteDataFetcherSpy(pack: pack)
        let state = Shared<AppState?>(value: AppStateFixture.state(
            routes: [old], currentRouteId: old.id
        ))
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = spy
        } operation: { UpdateRouteUseCase() }

        let actual = try await useCase(
            old, points: [point], passages: [], appState: state
        )

        #expect(actual.route == edited)
        #expect(state.wrappedValue?.districtState?.routes.first?.description == "server-edited")
        #expect(state.wrappedValue?.routeState?.points == [point])
        #expect(await spy.recordedCalls() == ["update:route"])
    }

    @Test("存在しなくなった期間のルートは更新後にローカルから除去する")
    func removesRouteWithMissingPeriod() async throws {
        let obsolete = AppStateFixture.route(periodId: "deleted-period")
        let pack = RoutePack(route: obsolete, points: [], passages: [])
        let spy = RouteDataFetcherSpy(pack: pack)
        let state = Shared<AppState?>(value: AppStateFixture.state(
            routes: [obsolete], currentRouteId: obsolete.id
        ))
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = spy
        } operation: { UpdateRouteUseCase() }

        _ = try await useCase(obsolete, points: [], passages: [], appState: state)

        #expect(state.wrappedValue?.districtState?.routes.isEmpty == true)
        #expect(state.wrappedValue?.routeState == nil)
    }

    @Test("更新APIの失敗は現在の状態を変更しない")
    func failureLeavesStateUntouched() async {
        let route = AppStateFixture.route()
        let original = AppStateFixture.state(routes: [route], currentRouteId: route.id)
        let state = Shared<AppState?>(value: original)
        let spy = RouteDataFetcherSpy(
            pack: RoutePack(route: route, points: [], passages: []),
            shouldFail: true
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[RouteDataFetcherKey.self] = spy
        } operation: { UpdateRouteUseCase() }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(route, points: [], passages: [], appState: state)
        }
        #expect(state.wrappedValue == original)
    }
}
