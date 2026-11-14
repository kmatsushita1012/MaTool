import ComposableArchitecture
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
        } withDependencies: { $0.installTestSpies() }

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
        } withDependencies: { $0.installTestSpies() }
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
        } withDependencies: { $0.installTestSpies() }

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

    private func makeState(
        routeId: Route.ID? = nil,
        routes: [Route] = [AppStateFixture.route()]
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
            appState: Shared<AppState?>(value: AppStateFixture.state(routes: routes)),
            mapRegion: mapRegion,
            toast: Shared<MapToast?>(value: nil)
        )
    }
}
