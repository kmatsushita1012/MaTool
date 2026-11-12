import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct LoadDistrictStateUseCaseTests {
    @Test("地区パックを取得して選択地区とルートを設定する")
    func savesFetchedDistrictPack() async throws {
        let route = AppStateFixture.route()
        let pack = LaunchDistrictPack(
            performances: [], routes: [route], points: [],
            passages: [], currentRouteId: route.id
        )
        let spy = SceneDataFetcherSpy(response: pack)
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[SceneDataFetcherKey.self] = spy
        } operation: { LoadDistrictStateUseCase() }

        let returned = try await useCase(districtId: "district", appState: state)

        #expect(returned.routes == [route])
        #expect(state.wrappedValue?.districtState?.districtId == "district")
        #expect(state.wrappedValue?.routeState?.route.id == route.id)
        #expect(await spy.districtLaunchCallCount() == 1)
    }

    @Test("地区パックを取得しても現在の地区が存在しなければ反映しない")
    func unknownDistrictDoesNotCreateLocalState() async throws {
        let route = AppStateFixture.route()
        let pack = LaunchDistrictPack(
            performances: [], routes: [route], points: [],
            passages: [], currentRouteId: route.id
        )
        let spy = SceneDataFetcherSpy(response: pack)
        let state = Shared<AppState?>(value: AppStateFixture.state(selectedDistrictId: nil))
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[SceneDataFetcherKey.self] = spy
        } operation: { LoadDistrictStateUseCase() }

        _ = try await useCase(districtId: "unknown", periodId: nil, appState: state)

        #expect(state.wrappedValue?.districtState == nil)
        #expect(state.wrappedValue?.routeState == nil)
    }

    @Test("nilのAppStateでも取得要求は実行するがローカル状態は作らない")
    func nilAppStateIsNotRecreated() async throws {
        let pack = LaunchDistrictPack(
            performances: [], routes: [], points: [], passages: [],
            currentRouteId: nil
        )
        let spy = SceneDataFetcherSpy(response: pack)
        let state = Shared<AppState?>(value: nil)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[SceneDataFetcherKey.self] = spy
        } operation: { LoadDistrictStateUseCase() }

        _ = try await useCase(districtId: "district", appState: state)

        #expect(state.wrappedValue == nil)
        #expect(await spy.districtLaunchCallCount() == 1)
    }
}
