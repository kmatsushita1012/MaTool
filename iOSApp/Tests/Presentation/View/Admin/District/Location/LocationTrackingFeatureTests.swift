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

    @Test("権限ボタンはUseCaseから実際の権限状態を読み、適切なSheetを表示する")
    @MainActor
    func permissionButtonReadsUseCase() async {
        let usecase = TrackingLocationUsecaseSpy(
            permission: .init(authorizationStatus: .denied, hasRequestedAlwaysLocationPermission: true)
        )
        let store = TestStore(initialState: makeState(authorized: .authorizedAlways)) {
            LocationTrackingFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.locationUsecase = usecase
        }
        await store.send(.locationPermissionButtonTapped)
        await store.receive(.locationPermissionButtonStateReceived(.init(
            authorizationStatus: .denied,
            hasRequestedAlwaysLocationPermission: true
        ))) {
            $0.showsUserLocation = false
            $0.isAlwaysLocationAuthorized = false
            $0.locationPermissionSheetMode = .settings
            $0.isLocationPermissionSheetPresented = true
        }
        #expect(await usecase.permissionQueries == 1)
        await store.finish()
    }

    @Test("権限Sheetを続行したら許可を要求し、設定復帰時は権限を再読込する")
    @MainActor
    func settingsSheetDismissalRequestsAndRefreshes() async {
        let permission = LocationPermissionState(
            authorizationStatus: .authorizedAlways,
            hasRequestedAlwaysLocationPermission: true
        )
        let usecase = TrackingLocationUsecaseSpy(permission: permission)
        var state = makeState(authorized: .denied)
        state.locationPermissionSheetMode = .settings
        state.isLocationPermissionSheetPresented = true
        state.shouldRequestLocationPermission = true
        let store = TestStore(initialState: state) {
            LocationTrackingFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.locationUsecase = usecase
        }
        await store.send(.locationPermissionSheetDismissed) {
            $0.shouldRequestLocationPermission = false
        }
        await store.receive(.locationPermissionStateRefreshed(permission)) {
            $0.showsUserLocation = true
            $0.isAlwaysLocationAuthorized = true
        }
        #expect(await usecase.permissionRequests == 1)
        #expect(await usecase.permissionQueries == 1)
        await store.finish()
    }

    @Test("権限が十分なら追跡開始はUseCaseへIDと送信間隔を渡す")
    @MainActor
    func trackingStartsWithSelectedInterval() async {
        let permission = LocationPermissionState(
            authorizationStatus: .authorizedAlways,
            hasRequestedAlwaysLocationPermission: true
        )
        let usecase = TrackingLocationUsecaseSpy(permission: permission)
        let store = TestStore(initialState: makeState(authorized: .authorizedAlways)) {
            LocationTrackingFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.locationUsecase = usecase
        }
        await store.send(.binding(.set(\.isTracking, true))) {
            $0.isTracking = true
        }
        await store.receive(.locationPermissionStateRefreshed(permission))
        await store.receive(.trackingStartResultReceived(.started(permission)))
        #expect(await usecase.startCalls == ["district:60"])
        #expect(store.state.isTracking)
        await store.finish()
    }

    @Test("追跡を停止すると位置削除と履歴記録を行い、二重送信はしない")
    @MainActor
    func trackingStopDeletesLocation() async {
        let permission = LocationPermissionState(
            authorizationStatus: .authorizedAlways,
            hasRequestedAlwaysLocationPermission: true
        )
        let usecase = TrackingLocationUsecaseSpy(permission: permission)
        let delete = TrackingDeleteLocationSpy()
        let store = TestStore(initialState: makeState(authorized: .authorizedAlways, isTracking: true)) {
            LocationTrackingFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.locationUsecase = usecase
            $0[DeleteLocationUseCaseKey.self] = delete
        }
        await store.send(.binding(.set(\.isTracking, false))) {
            $0.isTracking = false
        }
        await store.receive(.locationPermissionStateRefreshed(permission))
        await store.finish()
        #expect(await usecase.stopIDs == ["district"])
        #expect(await usecase.deleteRecords == 1)
        #expect(await delete.deletedIDs == ["district"])
    }

    @Test("Tracking結果が到着した後にすでに停止していたら位置データを削除する")
    @MainActor
    func lateStartResultStillStopsLocation() async {
        let permission = LocationPermissionState(
            authorizationStatus: .authorizedAlways,
            hasRequestedAlwaysLocationPermission: true
        )
        let usecase = TrackingLocationUsecaseSpy(permission: permission)
        let delete = TrackingDeleteLocationSpy()
        let store = TestStore(initialState: makeState()) {
            LocationTrackingFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.locationUsecase = usecase
            $0[DeleteLocationUseCaseKey.self] = delete
        }
        await store.send(.trackingStartResultReceived(.started(permission))) {
            $0.showsUserLocation = true
            $0.isAlwaysLocationAuthorized = true
        }
        await store.finish()
        #expect(await usecase.stopIDs == ["district"])
        #expect(await delete.deletedIDs == ["district"])
    }

    @Test("位置更新通知はSaveLocationUseCaseへ渡して成功履歴を記録する")
    @MainActor
    func locationUpdatesAreSavedAndRecorded() async {
        let usecase = TrackingLocationUsecaseSpy(permission: .init(
            authorizationStatus: .authorizedAlways, hasRequestedAlwaysLocationPermission: true
        ))
        let save = TrackingSaveLocationSpy()
        let store = TestStore(initialState: makeState()) {
            LocationTrackingFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.locationUsecase = usecase
            $0[SaveLocationUseCaseKey.self] = save
        }
        let location = FloatLocation(
            id: "loc", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        await store.send(.locationUpdateRequested(location))
        await store.finish()
        #expect(await save.savedIDs == ["loc"])
        #expect(await usecase.updatedIDs == ["loc"])
    }

    @Test("位置保存に失敗した場合は位置更新成功履歴を残さずエラー履歴を残す")
    @MainActor
    func failedLocationUpdateRecordsActualError() async {
        let error = AppError.be(.network("offline"))
        let usecase = TrackingLocationUsecaseSpy(permission: .init(
            authorizationStatus: .authorizedAlways, hasRequestedAlwaysLocationPermission: true
        ))
        let save = TrackingSaveLocationSpy(error: error)
        let store = TestStore(initialState: makeState()) {
            LocationTrackingFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.locationUsecase = usecase
            $0[SaveLocationUseCaseKey.self] = save
        }
        let location = FloatLocation(
            id: "loc", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        await store.send(.locationUpdateRequested(location))
        await store.finish()
        #expect(await save.savedIDs == ["loc"])
        #expect(await usecase.updatedIDs.isEmpty)
        #expect(await usecase.errors == [error.message])
    }

    @Test("位置履歴の初期ロードをUseCaseから取得し画面Stateに取り込む")
    @MainActor
    func onAppearLoadsInitialHistory() async {
        let location = FloatLocation(
            id: "previous", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let usecase = TrackingLocationUsecaseSpy(
            permission: .init(authorizationStatus: .authorizedAlways,
                              hasRequestedAlwaysLocationPermission: true),
            history: [.update(location)]
        )
        let store = TestStore(initialState: makeState()) {
            LocationTrackingFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.locationUsecase = usecase
        }
        await store.send(.onAppear)
        await store.receive(.historyUpdated([.update(location)])) {
            $0.history = [.update(location)]
        }
        await store.finish()
        #expect(await usecase.historyQueries == 1)
    }

    @Test("追跡停止時の削除失敗は停止処理を取り消さずエラー履歴に残す")
    @MainActor
    func trackingStopDeleteFailureRecordsError() async {
        let error = AppError.be(.network("delete offline"))
        let permission = LocationPermissionState(
            authorizationStatus: .authorizedAlways,
            hasRequestedAlwaysLocationPermission: true
        )
        let usecase = TrackingLocationUsecaseSpy(permission: permission)
        let delete = TrackingDeleteLocationSpy(error: error)
        let store = TestStore(initialState: makeState(authorized: .authorizedAlways, isTracking: true)) {
            LocationTrackingFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.locationUsecase = usecase
            $0[DeleteLocationUseCaseKey.self] = delete
        }
        store.exhaustivity = .off

        await store.send(.binding(.set(\.isTracking, false)))
        await store.receive(.locationPermissionStateRefreshed(permission))
        await store.finish()

        #expect(!store.state.isTracking)
        #expect(await usecase.stopIDs == ["district"])
        #expect(await delete.deletedIDs == ["district"])
        #expect(await usecase.deleteRecords == 0)
        #expect(await usecase.errors == [error.message])
    }

    @Test("非同期追跡開始の結果が遅れて到着し削除も失敗した場合は理由を記録する")
    @MainActor
    func lateTrackingStartDeleteFailureRecordsError() async {
        let error = AppError.be(.network("delete offline"))
        let permission = LocationPermissionState(
            authorizationStatus: .authorizedAlways,
            hasRequestedAlwaysLocationPermission: true
        )
        let usecase = TrackingLocationUsecaseSpy(permission: permission)
        let delete = TrackingDeleteLocationSpy(error: error)
        let store = TestStore(initialState: makeState()) {
            LocationTrackingFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.locationUsecase = usecase
            $0[DeleteLocationUseCaseKey.self] = delete
        }
        store.exhaustivity = .off

        await store.send(.trackingStartResultReceived(.started(permission)))
        await store.finish()

        #expect(!store.state.isTracking)
        #expect(store.state.isAlwaysLocationAuthorized)
        #expect(await usecase.stopIDs == ["district"])
        #expect(await delete.deletedIDs == ["district"])
        #expect(await usecase.deleteRecords == 0)
        #expect(await usecase.errors == [error.message])
    }

    @Test("起動後の位置履歴ストリーム更新は初期履歴を新しい履歴へ置き換える")
    @MainActor
    func streamedHistoryUpdatesReplaceInitialHistory() async {
        let initialLocation = FloatLocation(
            id: "old", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let newLocation = FloatLocation(
            id: "new", districtId: "district",
            coordinate: Coordinate(latitude: 35.1, longitude: 139.1)
        )
        let permission = LocationPermissionState(
            authorizationStatus: .authorizedAlways,
            hasRequestedAlwaysLocationPermission: true
        )
        let usecase = TrackingLocationUsecaseSpy(
            permission: permission,
            history: [.update(initialLocation)],
            streamedHistory: [[.update(newLocation)]]
        )
        let store = TestStore(initialState: makeState()) {
            LocationTrackingFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.locationUsecase = usecase
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(.historyUpdated([.update(initialLocation)]))
        await store.receive(.historyUpdated([.update(newLocation)]))
        #expect(store.state.history == [.update(newLocation)])
        await store.finish()
        #expect(await usecase.historyQueries == 1)
    }

    @Test("起動後の位置ストリーム更新は保存処理へ通知しサーバー応答を履歴に残す")
    @MainActor
    func streamedLocationUpdatesInvokeSaveUseCase() async {
        let location = FloatLocation(
            id: "streamed", districtId: "district",
            coordinate: Coordinate(latitude: 35.2, longitude: 139.2)
        )
        let permission = LocationPermissionState(
            authorizationStatus: .authorizedAlways,
            hasRequestedAlwaysLocationPermission: true
        )
        let usecase = TrackingLocationUsecaseSpy(
            permission: permission, streamedLocations: [location]
        )
        let save = TrackingSaveLocationSpy()
        let store = TestStore(initialState: makeState()) {
            LocationTrackingFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.locationUsecase = usecase
            $0[SaveLocationUseCaseKey.self] = save
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(.locationUpdateRequested(location))
        await store.finish()
        #expect(await save.savedIDs == ["streamed"])
        #expect(await usecase.updatedIDs == ["streamed"])
    }

}


private actor TrackingLocationUsecaseSpy: LocationUsecaseProtocol {
    let permission: LocationPermissionState
    let initialHistory: [Status]
    let streamedHistory: [[Status]]
    let streamedLocations: [FloatLocation]
    private(set) var permissionQueries = 0
    private(set) var permissionRequests = 0
    private(set) var historyQueries = 0
    private(set) var startCalls: [String] = []
    private(set) var stopIDs: [String] = []
    private(set) var updatedIDs: [FloatLocation.ID] = []
    private(set) var deleteRecords = 0
    private(set) var errors: [String] = []

    init(
        permission: LocationPermissionState,
        history: [Status] = [],
        streamedHistory: [[Status]] = [],
        streamedLocations: [FloatLocation] = []
    ) {
        self.permission = permission
        self.initialHistory = history
        self.streamedHistory = streamedHistory
        self.streamedLocations = streamedLocations
    }

    func prepareTracking() async -> LocationTrackingPreparation {
        LocationTrackingPreparation(isTracking: false, interval: nil, permissionState: permission)
    }
    func getLocationHistory() async -> [Status] {
        historyQueries += 1
        return initialHistory
    }
    func historyStream() async -> AsyncStream<[Status]> {
        AsyncStream { continuation in
            for history in streamedHistory { continuation.yield(history) }
            continuation.finish()
        }
    }
    func requestPermission() async { permissionRequests += 1 }
    func locationPermissionState() async -> LocationPermissionState {
        permissionQueries += 1
        return permission
    }
    func start(id: String, interval: Interval) async -> LocationTrackingStartResult {
        startCalls.append("\(id):\(interval.value)")
        return .started(permission)
    }
    func stop(id: String) async { stopIDs.append(id) }
    func getLocation() async -> AsyncValue<CLLocation> { .loading }
    func locationUpdateStream() async -> AsyncStream<FloatLocation> {
        AsyncStream { continuation in
            for location in streamedLocations { continuation.yield(location) }
            continuation.finish()
        }
    }
    func recordLocationUpdate(_ location: FloatLocation) async {
        updatedIDs.append(location.id)
    }
    func recordLocationDelete() async { deleteRecords += 1 }
    func recordLocationError(_ error: AppError) async { errors.append(error.message) }
}

private actor TrackingSaveLocationSpy: SaveLocationUseCaseProtocol {
    let error: AppError?
    private(set) var savedIDs: [FloatLocation.ID] = []

    init(error: AppError? = nil) { self.error = error }
    func callAsFunction(_ location: FloatLocation, appState: Shared<AppState?>) async throws -> FloatLocation {
        savedIDs.append(location.id)
        if let error { throw error }
        return location
    }
}

private actor TrackingDeleteLocationSpy: DeleteLocationUseCaseProtocol {
    let error: AppError?
    private(set) var deletedIDs: [District.ID] = []

    init(error: AppError? = nil) {
        self.error = error
    }

    func callAsFunction(districtId: District.ID, appState: Shared<AppState?>) async throws {
        deletedIDs.append(districtId)
        if let error { throw error }
    }
}
