import Clocks
import ComposableArchitecture
import Dependencies
import MapKit
import Shared
import Testing
@testable import iOSApp

struct PublicLocationsFeatureTests {
    @Test("地図の操作による表示領域BindingはShared MapRegionへ反映される")
    @MainActor
    func mapGestureBindingUpdatesSharedRegion() async {
        let fixture = LocationMapFixture(locations: [])
        let initial = fixture.makeState()
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 34.1, longitude: 138.2),
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.04)
        )
        let store = TestStore(initialState: initial) {
            PublicLocationsFeature()
        } withDependencies: { $0.installPublicLocationsTestDependencies() }
        store.exhaustivity = .off

        await store.send(.binding(.set(\.mapRegion, region)))
        #expect(store.state.mapRegion.center.latitude == 34.1)
        #expect(store.state.mapRegion.center.longitude == 138.2)
        await store.finish()
    }

    @Test("初回表示では配信中の位置全体に地図をfitする")
    func initialStateFitsAllFloatLocations() {
        let fixture = LocationMapFixture(locations: [
            FloatLocation(id: "first", districtId: "first", coordinate: .init(latitude: 35, longitude: 139)),
            FloatLocation(id: "second", districtId: "second", coordinate: .init(latitude: 36, longitude: 141))
        ])

        let state = fixture.makeState()
        let region = state.$mapRegion.wrappedValue

        #expect(region.center.latitude == 35.5)
        #expect(region.center.longitude == 140)
        #expect(abs(region.span.latitudeDelta - 1.1) < 0.000001)
        #expect(abs(region.span.longitudeDelta - 2.2) < 0.000001)
    }

    @Test("位置がない場合は祭典基点を表示する")
    func emptyLocationsUseFestivalBase() {
        let fixture = LocationMapFixture(locations: [])

        let state = fixture.makeState()
        let region = state.$mapRegion.wrappedValue

        #expect(region.center.latitude == fixture.festival.base.latitude)
        #expect(region.center.longitude == fixture.festival.base.longitude)
        #expect(region.span.latitudeDelta == spanDelta)
        #expect(region.span.longitudeDelta == spanDelta)
    }

    @Test("再読込成功後は更新されたAppStateの位置全体に地図をfitする")
    @MainActor
    func reloadSuccessFitsUpdatedFloatLocations() async {
        let fixture = LocationMapFixture(locations: [
            FloatLocation(id: "first", districtId: "first", coordinate: .init(latitude: 35, longitude: 139))
        ])
        let state = fixture.makeState()
        let store = TestStore(initialState: state) {
            PublicLocationsFeature()
        }
        store.exhaustivity = .off

        fixture.appState.withLock { appState in
            appState?.festivalState.replaceFloatLocations(with: [
                FloatLocation(id: "first", districtId: "first", coordinate: .init(latitude: 34, longitude: 138)),
                FloatLocation(id: "second", districtId: "second", coordinate: .init(latitude: 37, longitude: 142))
            ])
        }

        await store.send(.reloadReceived(.success([])))

        let region = state.$mapRegion.wrappedValue
        #expect(region.center.latitude == 35.5)
        #expect(region.center.longitude == 140)
        #expect(abs(region.span.latitudeDelta - 3.3) < 0.000001)
        #expect(abs(region.span.longitudeDelta - 4.4) < 0.000001)
        await store.finish()
    }
    @Test("位置配信一覧の更新操作は祭典IDをUseCaseに渡して更新完了を受け取る")
    @MainActor
    func reloadTappedCallsFetchLocationUseCase() async {
        let fixture = LocationMapFixture(locations: [
            FloatLocation(id: "first", districtId: "first", coordinate: .init(latitude: 35, longitude: 139))
        ])
        let spy = FetchLocationUseCaseSpy(result: .success([]))
        let store = TestStore(initialState: fixture.makeState()) {
            PublicLocationsFeature()
        } withDependencies: {
            $0.installPublicLocationsTestDependencies()
            $0[FetchLocationUseCaseKey.self] = spy
        }

        store.exhaustivity = .off
        await store.send(.reloadTapped)
        await store.receive(.reloadReceived(.success([])))
        #expect(store.state.mapRegion.center.latitude == 35)
        #expect(store.state.mapRegion.center.longitude == 139)
        #expect(await spy.festivalIDs == [fixture.festival.id])
        await store.finish()
    }

    @Test("位置配信一覧のStateは配信データがある地区だけを含む")
    func stateFloatEntriesComeFromAppState() {
        let location = FloatLocation(
            id: "first", districtId: "first",
            coordinate: .init(latitude: 35.5, longitude: 139.5)
        )
        let fixture = LocationMapFixture(locations: [location])
        let state = fixture.makeState()

        #expect(state.festivalId == fixture.festival.id)
        #expect(state.floats.count == 1)
        #expect(state.floats.first?.floatLocation.id == location.id)
        #expect(state.floats.first?.district.id == "first")
    }

    @Test("配信中の町を選択すると地図中心をその町の最新位置に移動する")
    @MainActor
    func selectedFloatFocusesBroadcastCoordinate() async throws {
        let location = FloatLocation(
            id: "first", districtId: "first",
            coordinate: .init(latitude: 34.5, longitude: 138.3)
        )
        let fixture = LocationMapFixture(locations: [location])
        let state = fixture.makeState()
        let entry = try #require(state.floats.first)
        let store = TestStore(initialState: state) {
            PublicLocationsFeature()
        } withDependencies: { $0.installPublicLocationsTestDependencies() }
        store.exhaustivity = .off

        await store.send(.floatFocusSelected(entry))
        #expect(store.state.mapRegion.center.latitude == 34.5)
        #expect(store.state.mapRegion.center.longitude == 138.3)
        await store.finish()
    }

    @Test("現在地の取得が成功したら地図の現在地ボタンで取得位置へ移動する")
    @MainActor
    func userFocusUsesLocationProvider() async {
        let fixture = LocationMapFixture(locations: [])
        let spy = LocationsMapLocationSpy(result: .success(
            CLLocation(latitude: 35.65, longitude: 139.75)
        ))
        let store = TestStore(initialState: fixture.makeState()) {
            PublicLocationsFeature()
        } withDependencies: {
            $0.installPublicLocationsTestDependencies()
            $0.mapLocationProvider = spy
        }
        store.exhaustivity = .off

        await store.send(.userFocusTapped)
        await store.receive(.userLocationReceived(Coordinate(latitude: 35.65, longitude: 139.75)))
        #expect(store.state.mapRegion.center.latitude == 35.65)
        #expect(store.state.mapRegion.center.longitude == 139.75)
        #expect(await spy.requests == 1)
        await store.finish()
    }

    @Test("位置データ再取得エラーは取得を成功扱いせず通知を表示する")
    @MainActor
    func reloadFailureShowsActualError() async {
        let fixture = LocationMapFixture(locations: [])
        let store = TestStore(initialState: fixture.makeState()) {
            PublicLocationsFeature()
        } withDependencies: { $0.installPublicLocationsTestDependencies() }
        store.exhaustivity = .off

        let error = AppError.be(.network("offline"))
        await store.send(.reloadReceived(.failure(error)))
        #expect(store.state.toast != nil)
        await store.send(.toastDismissed)
        #expect(store.state.toast == nil)
        await store.finish()
    }

    @Test("現在地読み込み中なら失敗メッセージを出し、閉じると通知が消える")
    @MainActor
    func loadingLocationShowsUnavailableMessage() async {
        let spy = LocationsMapLocationSpy(result: .loading)
        let fixture = LocationMapFixture(locations: [])
        let store = TestStore(initialState: fixture.makeState()) {
            PublicLocationsFeature()
        } withDependencies: {
            $0.installPublicLocationsTestDependencies()
            $0.mapLocationProvider = spy
        }
        store.exhaustivity = .off

        await store.send(.userFocusTapped)
        await store.receive(.userLocationFailed("現在地を取得できませんでした。"))
        #expect(store.state.toast != nil)
        await store.send(.toastDismissed)
        #expect(store.state.toast == nil)
        await store.finish()
    }

    @Test("初回の配信無し通知は画面表示時に閉じるタイマーを開始する")
    @MainActor
    func onAppearWithInitialNoticeSchedulesDismissal() async {
        let fixture = LocationMapFixture(locations: [])
        let store = TestStore(initialState: fixture.makeState()) {
            PublicLocationsFeature()
        } withDependencies: { $0.installPublicLocationsTestDependencies() }
        store.exhaustivity = .off

        #expect(store.state.toast != nil)
        await store.send(.onAppear)
        await store.send(.toastDismissed)
        #expect(store.state.toast == nil)
        await store.finish()
    }

    @Test("配信無しの通知は3秒後に自動消去され、残ったタイマーが再通知しない")
    @MainActor
    func initialNoticeExpiresAfterThreeSeconds() async {
        let clock = TestClock()
        let fixture = LocationMapFixture(locations: [])
        let initial = fixture.makeState()
        let store = TestStore(initialState: initial) {
            PublicLocationsFeature()
        } withDependencies: {
            $0.installPublicLocationsTestDependencies()
            $0.continuousClock = clock
        }
        store.exhaustivity = .off

        #expect(store.state.toast != nil)
        await store.send(.onAppear)
        await clock.advance(by: .seconds(3))
        await store.receive(.toastDismissed)
        #expect(store.state.toast == nil)
        await store.finish()
    }

    @Test("配信マーカーをタップするだけでは地図の中心や通知を変更しない")
    @MainActor
    func floatTapDoesNotRefocusMap() async throws {
        let location = FloatLocation(
            id: "first", districtId: "first",
            coordinate: .init(latitude: 35.5, longitude: 139.5)
        )
        let fixture = LocationMapFixture(locations: [location])
        let state = fixture.makeState()
        let entry = try #require(state.floats.first)
        let store = TestStore(initialState: state) {
            PublicLocationsFeature()
        } withDependencies: { $0.installPublicLocationsTestDependencies() }
        let before = store.state.mapRegion

        await store.send(.floatTapped(entry))
        #expect(store.state.mapRegion.center.latitude == before.center.latitude)
        #expect(store.state.mapRegion.center.longitude == before.center.longitude)
        await store.finish()
    }

    @Test("端末の現在地取得が失敗した場合は取得元エラーを通知して地図を動かさない")
    @MainActor
    func userLocationFailureShowsProviderError() async {
        let fixture = LocationMapFixture(locations: [])
        let error = AppError.be(.network("gps unavailable"))
        let provider = LocationsMapLocationSpy(result: .failure(error))
        let initial = fixture.makeState()
        let originalRegion = initial.mapRegion
        let store = TestStore(initialState: initial) {
            PublicLocationsFeature()
        } withDependencies: {
            $0.installPublicLocationsTestDependencies()
            $0.mapLocationProvider = provider
        }
        store.exhaustivity = .off

        await store.send(.userFocusTapped)
        await store.receive(.userLocationFailed(error.message))
        #expect(store.state.toast != nil)
        #expect(store.state.mapRegion.center.latitude == originalRegion.center.latitude)
        #expect(store.state.mapRegion.center.longitude == originalRegion.center.longitude)
        #expect(await provider.requests == 1)
        await store.send(.toastDismissed)
        await store.finish()
    }

    @Test("有効な現在地情報があれば初回表示で不要な通知タイマーは開始しない")
    @MainActor
    func onAppearWithoutToastLeavesMapUnchanged() async {
        let fixture = LocationMapFixture(locations: [
            FloatLocation(
                id: "active", districtId: "first",
                coordinate: .init(latitude: 35.4, longitude: 139.4)
            )
        ])
        let initial = fixture.makeState()
        let store = TestStore(initialState: initial) {
            PublicLocationsFeature()
        } withDependencies: { $0.installPublicLocationsTestDependencies() }
        let region = store.state.mapRegion

        #expect(store.state.toast == nil)
        await store.send(.onAppear)
        #expect(store.state.toast == nil)
        #expect(store.state.mapRegion.center.latitude == region.center.latitude)
        #expect(store.state.mapRegion.center.longitude == region.center.longitude)
        await store.finish()
    }

    @Test("祭典データが消えていても位置の再取得結果を安全に受け入れ地図を保持する")
    @MainActor
    func reloadSuccessWithoutAppStateDoesNotChangeMapRegion() async {
        let fixture = LocationMapFixture(locations: [])
        let initial = fixture.makeState()
        let oldRegion = initial.mapRegion
        fixture.appState.withLock { $0 = nil }
        let store = TestStore(initialState: initial) {
            PublicLocationsFeature()
        } withDependencies: { $0.installPublicLocationsTestDependencies() }
        store.exhaustivity = .off

        await store.send(.reloadReceived(.success([])))
        #expect(store.state.mapRegion.center.latitude == oldRegion.center.latitude)
        #expect(store.state.mapRegion.center.longitude == oldRegion.center.longitude)
        #expect(store.state.floats.isEmpty)
        await store.finish()
    }

}

private struct LocationMapFixture {
    let festival: Festival
    let appState: Shared<AppState?>

    init(locations: [FloatLocation]) {
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: .init(latitude: 35.2, longitude: 139.2)
        )
        self.festival = festival
        let districts = ["first", "second"].map { districtId in
            District(id: districtId, name: districtId, festivalId: festival.id)
        }
        appState = Shared(value: AppState(
            festivalPack: LaunchFestivalPack(
                festival: festival,
                year: 2026,
                districts: districts,
                periods: [],
                locations: locations,
                checkpoints: [],
                hazardSections: []
            )
        ))
    }

    func makeState() -> PublicLocationsFeature.State {
        PublicLocationsFeature.State(
            festivalId: festival.id,
            festival: festival,
            appState: appState,
            mapRegion: Shared(value: makeRegion(origin: festival.base, spanDelta: spanDelta)),
            toast: Shared(value: nil)
        )
    }
}

private actor LocationsMapLocationSpy: MapLocationProviderProtocol {
    let result: AsyncValue<CLLocation>
    private(set) var requests = 0

    init(result: AsyncValue<CLLocation>) { self.result = result }

    func requestPermission() async {}
    func startTracking() async {}
    func stopTracking() async {}
    func getLocation() async -> AsyncValue<CLLocation> {
        requests += 1
        return result
    }
    var isTracking: Bool { get async { false } }
}

private extension DependencyValues {
    mutating func installPublicLocationsTestDependencies() {
        installTestSpies()
        continuousClock = TestClock()
    }
}
