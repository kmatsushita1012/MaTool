import Clocks
import ComposableArchitecture
import Dependencies
import Foundation
import MapKit
import Shared
import Testing
@testable import iOSApp

struct PublicRouteFeatureTests {
    @Test("再生状態の判定は開始とシークのみ再生中とみなす")
    func replayRunningState() {
        #expect(PublicRouteFeature.Replay.start.isRunning)
        #expect(PublicRouteFeature.Replay.seek(0.25).isRunning)
        #expect(!PublicRouteFeature.Replay.stop.isRunning)
        #expect(!PublicRouteFeature.Replay.initial(nil).isRunning)
        #expect(!PublicRouteFeature.Replay.initial("route").isRunning)
    }

    @Test("再生・停止・シーク操作は再生状態に応じて正しく遷移する")
    @MainActor
    func playbackActionsRespectCurrentState() async {
        let store = TestStore(initialState: makeState(routeId: "route")) {
            PublicRouteFeature()
        } withDependencies: { $0.installPublicRouteTestDependencies() }

        await store.send(.didSeek(0.5))
        await store.send(.replayTapped) {
            $0.replay = .start
        }
        await store.send(.didSeek(0.5)) {
            $0.replay = .seek(0.5)
        }
        await store.send(.replayTapped) {
            $0.replay = .stop
        }
        await store.send(.didSeek(0.1))
        await store.send(.replayEnded)
        await store.finish()
    }

    @Test("選択中の経路と異なる取得結果は現在の選択を上書きしない")
    @MainActor
    func staleRouteResultIsIgnored() async {
        var state = makeState(routeId: "route")
        state.isRouteLoading = true
        let store = TestStore(initialState: state) {
            PublicRouteFeature()
        } withDependencies: { $0.installPublicRouteTestDependencies() }
        let pack = RoutePack(
            route: AppStateFixture.route(id: "another-route"),
            points: [], passages: []
        )

        await store.send(.routeLoaded(.success(pack))) {
            $0.isRouteLoading = false
        }
        #expect(store.state.selectedRouteId == "route")
        await store.finish()
    }

    @Test("読み込み成功でも経路が存在しなければ読み込み状態だけを解除する")
    @MainActor
    func missingRouteResultDoesNotResetSelection() async {
        var state = makeState(routeId: "route")
        state.isRouteLoading = true
        let store = TestStore(initialState: state) {
            PublicRouteFeature()
        } withDependencies: { $0.installPublicRouteTestDependencies() }

        await store.send(.routeLoaded(.success(nil))) {
            $0.isRouteLoading = false
        }
        #expect(store.state.selectedRouteId == "route")
        await store.finish()
    }

    @Test("経路・位置配信が無い地区には表示可能なコンテンツが無い")
    func emptyDistrictHasNoContent() {
        let state = makeState(routeId: nil, routes: [])
        #expect(!state.hasDisplayableContent)
        #expect(state.points.isEmpty)
        #expect(state.others.isEmpty)
        #expect(!state.isReplayEnable)
    }

    @Test("ルート非配信の町を開いたら位置配信と混同せず配信停止の通知を表示する")
    @MainActor
    func onAppearShowsNoRouteNotice() async {
        let store = TestStore(initialState: makeState(routeId: nil, routes: [])) {
            PublicRouteFeature()
        } withDependencies: { $0.installPublicRouteTestDependencies() }
        store.exhaustivity = .off

        await store.send(.onAppear)
        #expect(store.state.toast != nil)
        await store.send(.toastDismissed)
        #expect(store.state.toast == nil)
        await store.finish()
    }

    @Test("現在地の配信がある町では配信位置に地図の中心を合わせる")
    @MainActor
    func floatFocusUsesBroadcastCoordinate() async {
        let location = FloatLocation(
            id: "float-1", districtId: "district",
            coordinate: Coordinate(latitude: 35.25, longitude: 139.5)
        )
        let store = TestStore(initialState: makeState(locations: [location])) {
            PublicRouteFeature()
        } withDependencies: { $0.installPublicRouteTestDependencies() }
        store.exhaustivity = .off

        await store.send(.floatFocusTapped)
        #expect(store.state.mapRegion.center.latitude == 35.25)
        #expect(store.state.mapRegion.center.longitude == 139.5)
        #expect(store.state.toast == nil)
        await store.finish()
    }

    @Test("地図上の点を押すと対応するPointEntryを詳細状態に保持する")
    @MainActor
    func pointTapSelectsPointDetail() async {
        let point = Point(
            id: "point-1", routeId: "route",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let entry = PointEntry(point, checkpoint: nil, performance: nil)
        let store = TestStore(initialState: makeState(routeId: "route")) {
            PublicRouteFeature()
        } withDependencies: { $0.installPublicRouteTestDependencies() }
        await store.send(.pointTapped(entry)) {
            $0.detail = .point(entry)
        }
        #expect(store.state.detail?.id == "point-1")
        await store.finish()
    }

    @Test("経路を取得できたら読み込み表示を終了し選択した経路を維持する")
    @MainActor
    func matchingRouteResultClearsLoading() async {
        let route = AppStateFixture.route(id: "route")
        var state = makeState(routeId: route.id)
        state.isRouteLoading = true
        let store = TestStore(initialState: state) {
            PublicRouteFeature()
        } withDependencies: { $0.installPublicRouteTestDependencies() }
        store.exhaustivity = .off
        await store.send(.routeLoaded(.success(RoutePack(route: route, points: [], passages: []))))
        #expect(!store.state.isRouteLoading)
        #expect(store.state.selectedRouteId == route.id)
        await store.finish()
    }

    @Test("位置マーカータップは現在選択中の点や経路を解除しない")
    @MainActor
    func locationTapIsNoop() async {
        let location = FloatLocation(
            id: "float-1", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let state = makeState(routeId: "route", locations: [location])
        guard let entry = state.float else {
            Issue.record("expected the district float entry")
            return
        }
        let store = TestStore(initialState: state) {
            PublicRouteFeature()
        } withDependencies: { $0.installPublicRouteTestDependencies() }

        await store.send(.locationTapped(entry))
        #expect(store.state.selectedRouteId == "route")
        await store.finish()
    }

    private func makeState(
        routeId: Route.ID? = nil,
        routes: [Route] = [AppStateFixture.route()],
        locations: [FloatLocation] = []
    ) -> PublicRouteFeature.State {
        let district = AppStateFixture.district()
        let mapRegion = Shared(value: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35, longitude: 139),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        return PublicRouteFeature.State(
            districtId: district.id,
            district: district,
            routeId: routeId,
            appState: Shared<AppState?>(value: AppStateFixture.state(routes: routes, locations: locations)),
            mapRegion: mapRegion,
            toast: Shared<MapToast?>(value: nil)
        )
    }
    @Test("現在地取得に成功したら地図の中心を取得座標へ移動する")
    @MainActor
    func userFocusMovesMapToCurrentLocation() async {
        let provider = RouteMapLocationSpy(result: .success(
            CLLocation(latitude: 34.8, longitude: 138.2)
        ))
        let store = TestStore(initialState: makeState()) {
            PublicRouteFeature()
        } withDependencies: {
            $0.installPublicRouteTestDependencies()
            $0.mapLocationProvider = provider
        }
        store.exhaustivity = .off

        await store.send(.userFocusTapped)
        await store.receive(.userLocationReceived(Coordinate(latitude: 34.8, longitude: 138.2)))
        #expect(store.state.mapRegion.center.latitude == 34.8)
        #expect(store.state.mapRegion.center.longitude == 138.2)
        await store.finish()
        #expect(await provider.locationRequests == 1)
    }

    @Test("現在地が読み込み中なら位置取得失敗を表示して自動消去できる")
    @MainActor
    func unavailableUserLocationShowsToast() async {
        let provider = RouteMapLocationSpy(result: .loading)
        let store = TestStore(initialState: makeState()) {
            PublicRouteFeature()
        } withDependencies: {
            $0.installPublicRouteTestDependencies()
            $0.mapLocationProvider = provider
        }
        store.exhaustivity = .off

        await store.send(.userFocusTapped)
        await store.receive(.userLocationFailed("現在地を取得できませんでした。"))
        #expect(store.state.toast != nil)
        await store.send(.toastDismissed)
        #expect(store.state.toast == nil)
        await store.finish()
        #expect(await provider.locationRequests == 1)
    }

    @Test("位置配信中の町がなければ地図中心を変えず通知を示す")
    @MainActor
    func absentFloatLocationShowsUnavailableNotice() async {
        let store = TestStore(initialState: makeState()) {
            PublicRouteFeature()
        } withDependencies: { $0.installPublicRouteTestDependencies() }
        store.exhaustivity = .off
        let before = store.state.mapRegion

        await store.send(.floatFocusTapped)
        #expect(store.state.mapRegion.center.latitude == before.center.latitude)
        #expect(store.state.toast != nil)
        await store.send(.toastDismissed)
        #expect(store.state.toast == nil)
        await store.finish()
    }

    @Test("選択中の経路の読み込み失敗はユーザーへ理由を通知する")
    @MainActor
    func routeFailureProducesErrorToast() async {
        var state = makeState(routeId: "route")
        state.isRouteLoading = true
        let store = TestStore(initialState: state) {
            PublicRouteFeature()
        } withDependencies: { $0.installPublicRouteTestDependencies() }
        store.exhaustivity = .off
        let error = AppError.be(.network("offline"))

        await store.send(.routeLoaded(.failure(error)))
        #expect(!store.state.isRouteLoading)
        #expect(store.state.toast != nil)
        await store.send(.toastDismissed)
        #expect(store.state.toast == nil)
        await store.finish()
    }

    @Test("別の経路を選択したら選択IDを更新し、対応するUseCaseを起動する")
    @MainActor
    func selectingRouteLoadsSelectedRoute() async throws {
        let spy = RouteLoadUseCaseSpy()
        let state = makeState(routeId: nil)
        let entry = try #require(state.routes.first)
        let store = TestStore(initialState: state) {
            PublicRouteFeature()
        } withDependencies: {
            $0.installPublicRouteTestDependencies()
            $0[LoadRouteStateUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.selected(entry))
        await store.receive(.routeLoaded(.success(nil)))
        #expect(store.state.selectedRouteId == entry.id)
        #expect(store.state.replay == .initial(entry.id))
        #expect(!store.state.isRouteLoading)
        #expect(await spy.routeIDs == [entry.id])
        await store.finish()
    }

    @Test("経路表示中に再訪したときは同じ経路を再読込する")
    @MainActor
    func onAppearReloadsActiveRoute() async {
        let spy = RouteLoadUseCaseSpy()
        let store = TestStore(initialState: makeState(routeId: "route")) {
            PublicRouteFeature()
        } withDependencies: {
            $0.installPublicRouteTestDependencies()
            $0[LoadRouteStateUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(.routeLoaded(.success(nil)))
        #expect(!store.state.isRouteLoading)
        #expect(await spy.routeIDs == ["route"])
        await store.finish()
    }

}

private actor RouteMapLocationSpy: MapLocationProviderProtocol {
    let result: AsyncValue<CLLocation>
    private(set) var locationRequests = 0

    init(result: AsyncValue<CLLocation>) { self.result = result }

    func requestPermission() async {}
    func startTracking() async {}
    func stopTracking() async {}
    func getLocation() async -> AsyncValue<CLLocation> {
        locationRequests += 1
        return result
    }
    var isTracking: Bool { get async { false } }
}

private actor RouteLoadUseCaseSpy: LoadRouteStateUseCaseProtocol {
    private(set) var routeIDs: [Route.ID] = []

    func callAsFunction(routeId: Route.ID, appState: Shared<AppState?>) async throws -> RoutePack? {
        routeIDs.append(routeId)
        return nil
    }
}

private extension DependencyValues {
    mutating func installPublicRouteTestDependencies() {
        installTestSpies()
        continuousClock = TestClock()
        date.now = Date(timeIntervalSince1970: 0)
    }
}
