import ComposableArchitecture
import CoreLocation
import Shared
import Testing
@testable import iOSApp

struct LocationTrackingFeatureTests {
    @Test("権限状態ごとに位置情報許可シナリオを分ける")
    func 権限状態ごとに位置情報許可シナリオを分ける() {
        #expect(
            LocationPermissionSheetMode(
                authorizationStatus: .notDetermined,
                hasRequestedAlwaysLocationPermission: false
            )
                == .requestWhenInUseAndAlways
        )
        #expect(
            LocationPermissionSheetMode(
                authorizationStatus: .authorizedWhenInUse,
                hasRequestedAlwaysLocationPermission: false
            )
                == .requestAlways
        )
        #expect(
            LocationPermissionSheetMode(
                authorizationStatus: .authorizedWhenInUse,
                hasRequestedAlwaysLocationPermission: true
            )
                == .settings
        )
        #expect(
            LocationPermissionSheetMode(
                authorizationStatus: .denied,
                hasRequestedAlwaysLocationPermission: false
            )
                == .settings
        )
        #expect(
            LocationPermissionSheetMode(
                authorizationStatus: .restricted,
                hasRequestedAlwaysLocationPermission: false
            )
                == .settings
        )
        #expect(
            LocationPermissionSheetMode(
                authorizationStatus: .authorizedAlways,
                hasRequestedAlwaysLocationPermission: true
            ) == nil
        )
    }
    private func makeState(
        authorized: CLAuthorizationStatus = .notDetermined,
        isTracking: Bool = false
    ) -> LocationTrackingFeature.State {
        LocationTrackingFeature.State(
            id: "district", isTracking: isTracking,
            selectedInterval: .sample,
            permissionState: LocationPermissionState(
                authorizationStatus: authorized,
                hasRequestedAlwaysLocationPermission: false
            ),
            appState: Shared(value: Optional(AppStateFixture.state()))
        )
    }

    @Test("初期状態はLocation権限とTrackerの選択状態を一致させる")
    func initialStateUsesPermissionAndTrackingFlags() {
        let state = makeState(authorized: .authorizedAlways, isTracking: true)
        #expect(state.id == "district")
        #expect(state.isTracking)
        #expect(!state.isPickerEnabled)
        #expect(state.showsUserLocation)
        #expect(state.isAlwaysLocationAuthorized)
        #expect(!state.isLocationPermissionSheetPresented)
    }

    @Test("開始前は送信間隔のPickerを操作できる")
    func pickerEnabledOnlyWhenTrackingIsStopped() {
        #expect(makeState(isTracking: false).isPickerEnabled)
        #expect(!makeState(isTracking: true).isPickerEnabled)
    }

    @Test("権限状態の再読込は現在地表示可否とAlways許可を反映する")
    @MainActor
    func permissionRefreshUpdatesFlags() async {
        let store = TestStore(initialState: makeState()) {
            LocationTrackingFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.locationPermissionStateRefreshed(.init(
            authorizationStatus: .authorizedWhenInUse,
            hasRequestedAlwaysLocationPermission: false
        ))) {
            $0.showsUserLocation = true
        }
        await store.send(.locationPermissionStateRefreshed(.init(
            authorizationStatus: .authorizedAlways,
            hasRequestedAlwaysLocationPermission: true
        ))) {
            $0.isAlwaysLocationAuthorized = true
        }
        await store.finish()
    }

    @Test("許可ボタンは不足権限に対応するSheetの表示状態を更新する")
    @MainActor
    func receivedPermissionPromptsUser() async {
        let store = TestStore(initialState: makeState()) {
            LocationTrackingFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.locationPermissionButtonStateReceived(.init(
            authorizationStatus: .notDetermined,
            hasRequestedAlwaysLocationPermission: false
        )))
        #expect(store.state.locationPermissionSheetMode == .requestWhenInUseAndAlways)
        #expect(store.state.isLocationPermissionSheetPresented)
        await store.send(.locationPermissionButtonStateReceived(.init(
            authorizationStatus: .authorizedAlways,
            hasRequestedAlwaysLocationPermission: true
        ))) {
            $0.showsUserLocation = true
            $0.isAlwaysLocationAuthorized = true
            $0.locationPermissionSheetMode = nil
            $0.isLocationPermissionSheetPresented = false
        }
        await store.finish()
    }

    @Test("追跡開始に成功すると許可フラグを更新して追跡を維持する")
    @MainActor
    func acceptedStartRetainsTracking() async {
        let store = TestStore(initialState: makeState(isTracking: true)) {
            LocationTrackingFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.trackingStartResultReceived(.started(.init(
            authorizationStatus: .authorizedAlways,
            hasRequestedAlwaysLocationPermission: true
        )))) {
            $0.showsUserLocation = true
            $0.isAlwaysLocationAuthorized = true
        }
        #expect(store.state.isTracking)
        await store.finish()
    }

    @Test("Alwaysの許可が不足していれば追跡をオフにし許可Sheetを提示する")
    @MainActor
    func deniedStartStopsTrackingAndPrompts() async {
        let store = TestStore(initialState: makeState(isTracking: true)) {
            LocationTrackingFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.trackingStartResultReceived(.permissionRequired(.init(
            authorizationStatus: .authorizedWhenInUse,
            hasRequestedAlwaysLocationPermission: false
        )))) {
            $0.isTracking = false
            $0.showsUserLocation = true
            $0.locationPermissionSheetMode = .requestAlways
            $0.isLocationPermissionSheetPresented = true
        }
        await store.finish()
    }

    @Test("追跡していない場合の許可不足はSheet表示を要求しない")
    @MainActor
    func deniedStartWhileStoppedDoesNotPrompt() async {
        let store = TestStore(initialState: makeState(isTracking: false)) {
            LocationTrackingFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.trackingStartResultReceived(.permissionRequired(.init(
            authorizationStatus: .denied,
            hasRequestedAlwaysLocationPermission: false
        ))))
        #expect(store.state.isLocationPermissionSheetPresented)
        await store.finish()
    }

    @Test("端末の位置サービスが停止中なら追跡状態を確実に解除する")
    @MainActor
    func disabledLocationServiceStopsTracking() async {
        let store = TestStore(initialState: makeState(isTracking: true)) {
            LocationTrackingFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.trackingStartResultReceived(.locationServicesDisabled)) {
            $0.isTracking = false
        }
        await store.finish()
    }

    @Test("権限Sheetの続行はSheetを閉じて権限要求フラグを有効にする")
    @MainActor
    func permissionProceedClosesSheet() async {
        var initial = makeState()
        initial.isLocationPermissionSheetPresented = true
        let store = TestStore(initialState: initial) {
            LocationTrackingFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.locationPermissionProceedTapped) {
            $0.shouldRequestLocationPermission = true
            $0.isLocationPermissionSheetPresented = false
        }
        await store.finish()
    }

    @Test("取得済みの位置履歴は最新の内容で置き換える")
    @MainActor
    func historyUpdateReplacesPreviousHistory() async {
        let store = TestStore(initialState: makeState()) {
            LocationTrackingFeature()
        } withDependencies: { $0.installTestSpies() }
        let location = FloatLocation(
            id: "loc", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )

        await store.send(.historyUpdated([.update(location)])) {
            $0.history = [.update(location)]
        }
        await store.send(.historyUpdated([])) {
            $0.history = []
        }
        await store.finish()
    }

    @Test("許可Sheetの通常Dismissは要求フラグを消去する")
    @MainActor
    func dismissedSheetClearsRequestFlag() async {
        var initial = makeState()
        initial.shouldRequestLocationPermission = true
        let store = TestStore(initialState: initial) {
            LocationTrackingFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.locationPermissionSheetDismissed) {
            $0.shouldRequestLocationPermission = false
        }
        await store.finish()
    }

}
