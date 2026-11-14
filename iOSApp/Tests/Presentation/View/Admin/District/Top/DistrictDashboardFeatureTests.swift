import ComposableArchitecture
import CoreLocation
import Foundation
import Shared
import Testing
@testable import iOSApp

struct DistrictDashboardFeatureTests {
    @Test("地区ダッシュボードの読み込み状態は画面遷移とPDF出力を区別する")
    func loadingFlagsReflectCurrentOperation() {
        var state = makeState()
        #expect(!state.isLoading)
        #expect(!state.isNavigationLoading)
        #expect(!state.isSubmissionExportLoading)
        #expect(!state.isTableExportLoading)

        state.isRouteLoading = true
        #expect(state.isLoading)
        #expect(state.isNavigationLoading)
        state.isRouteLoading = false

        state.isAWSLoading = true
        #expect(state.isNavigationLoading)
        state.isAWSLoading = false

        state.isLocationLoading = true
        #expect(state.isNavigationLoading)
        state.isLocationLoading = false

        state.isSettingsLoading = true
        #expect(state.isNavigationLoading)
        state.isSettingsLoading = false

        state.activeExportKind = .submission
        #expect(state.isLoading)
        #expect(state.isSubmissionExportLoading)
        #expect(!state.isTableExportLoading)
        state.activeExportKind = .table
        #expect(state.isTableExportLoading)
        #expect(!state.isSubmissionExportLoading)
        state.activeExportKind = nil
        #expect(!state.isLoading)
    }

    @Test("パスワードとメールアドレスの変更画面をそれぞれ開ける")
    @MainActor
    func credentialChangeScreensAreDistinct() async {
        let passwordStore = TestStore(initialState: makeState()) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        await passwordStore.send(.changePasswordTapped) {
            $0.destination = .changePassword(ChangePasswordFeature.State())
        }
        await passwordStore.finish()

        let emailStore = TestStore(initialState: makeState()) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        await emailStore.send(.updateEmailTapped) {
            $0.destination = .updateEmail(UpdateEmailFeature.State())
        }
        await emailStore.finish()
    }

    @Test("経路の読み込み結果がnilなら遷移せずローディングだけ終了する")
    @MainActor
    func missingRouteDoesNotOpenEditor() async {
        var state = makeState()
        state.isRouteLoading = true
        let store = TestStore(initialState: state) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        await store.send(.routeEditReceived(.success(nil))) {
            $0.isRouteLoading = false
        }
        #expect(store.state.destination == nil)
        await store.finish()
    }

    @Test("経路・設定情報の取得失敗は実際のエラー内容を保持する")
    @MainActor
    func routeAndSettingsFailureShowDetails() async {
        let error = AppError.be(.network("offline"))
        var routeState = makeState()
        routeState.isRouteLoading = true
        let routeStore = TestStore(initialState: routeState) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        await routeStore.send(.routeEditReceived(.failure(error))) {
            $0.isRouteLoading = false
            $0.alert = AlertFeature.error(error.message)
        }
        await routeStore.finish()

        var settingsState = makeState()
        settingsState.isSettingsLoading = true
        let settingsStore = TestStore(initialState: settingsState) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        await settingsStore.send(.settingsPrepared(.failure(error))) {
            $0.isSettingsLoading = false
            $0.alert = AlertFeature.error("設定画面の準備に失敗しました。\n\(error.message)")
        }
        await settingsStore.finish()
    }

    @Test("PDF出力の成功時は共有用URLを保存し出力中表示を解除する")
    @MainActor
    func successfulExportKeepsResultURL() async {
        var state = makeState()
        state.activeExportKind = .submission
        let store = TestStore(initialState: state) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        let url = URL(string: "file:///tmp/district.pdf")!

        await store.send(.exportReceived(.success(url))) {
            $0.activeExportKind = nil
            $0.url = url
        }
        #expect(!store.state.isLoading)
        await store.finish()
    }

    @Test("PDF出力失敗時は出力中表示を解除しエラーを示す")
    @MainActor
    func failedExportShowsReason() async {
        let error = AppError.be(.network("export unavailable"))
        var state = makeState()
        state.activeExportKind = .table
        let store = TestStore(initialState: state) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.exportReceived(.failure(error))) {
            $0.activeExportKind = nil
            $0.alert = AlertFeature.error(error.message)
        }
        await store.finish()
    }

    @Test("ログアウトの成功と失敗ではローディング解除を共通化し失敗だけ警告する")
    @MainActor
    func signOutResultsAreHandled() async {
        let error = AppError.be(.network("offline"))
        var failureState = makeState()
        failureState.isAWSLoading = true
        let failureStore = TestStore(initialState: failureState) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        await failureStore.send(.signOutReceived(.failure(error))) {
            $0.isAWSLoading = false
            $0.alert = AlertFeature.error("ログアウトに失敗しました。 \(error.message)")
        }
        await failureStore.finish()

        var successState = makeState()
        successState.isAWSLoading = true
        let successStore = TestStore(initialState: successState) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        await successStore.send(.signOutReceived(.success(.onboarding))) {
            $0.isAWSLoading = false
        }
        await successStore.finish()
    }

    @Test("地区の編集ボタンはロード済みの地区状態を編集画面へ引き継ぐ")
    @MainActor
    func editTappedOpensLoadedDistrict() async {
        let store = TestStore(initialState: makeState()) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.onEdit)
        #expect(store.state.destination?.edit?.district.id == "district")
        await store.finish()
    }

    @Test("経路が未作成の期間は新規経路編集モードで開く")
    @MainActor
    func emptyRouteSlotOpensCreationMode() async {
        let store = TestStore(initialState: makeState()) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off
        await store.send(.onRouteEdit(RouteSlot(
            period: AppStateFixture.period(), route: nil
        )))
        #expect(store.state.destination?.route?.mode == .create)
        #expect(store.state.destination?.route?.route.periodId == "period")
        await store.finish()
    }

    @Test("既存経路のロード成功ではRoutePackの内容をプレビュードラフトへ渡す")
    @MainActor
    func loadedRouteOpensUpdateEditor() async {
        let route = AppStateFixture.route()
        let pack = RoutePack(route: route, points: [], passages: [])
        var initial = makeState()
        initial.isRouteLoading = true
        let store = TestStore(initialState: initial) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.routeEditReceived(.success(pack)))
        #expect(!store.state.isRouteLoading)
        #expect(store.state.destination?.route?.mode == .update)
        #expect(store.state.destination?.route?.route.id == route.id)
        await store.finish()
    }

    @Test("位置配信設定の準備完了時は配信状態と許可状態を保持して画面を開く")
    @MainActor
    func locationPreparationPreservesTrackingState() async {
        var initial = makeState()
        initial.isLocationLoading = true
        let store = TestStore(initialState: initial) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.locationPrepared(
            isTracking: true,
            interval: .init(label: "5分", value: 300),
            permissionState: .init(authorizationStatus: .authorizedAlways,
                                   hasRequestedAlwaysLocationPermission: true)
        ))
        #expect(!store.state.isLocationLoading)
        #expect(store.state.destination?.location?.id == "district")
        #expect(store.state.destination?.location?.selectedInterval.value == 300)
        #expect(store.state.destination?.location?.isTracking == true)
        await store.finish()
    }

    @Test("設定情報の取得成功では地区管理者の権限を設定画面へ渡す")
    @MainActor
    func preparedSettingsOpenDistrictRole() async {
        var initial = makeState()
        initial.isSettingsLoading = true
        let store = TestStore(initialState: initial) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.settingsPrepared(.success(.init(
            festivals: [AppStateFixture.festival()],
            selection: SceneSelection(festivalId: "festival", districtId: "district")
        ))))
        #expect(!store.state.isSettingsLoading)
        #expect(store.state.destination?.settings?.userRole == .district("district"))
        await store.finish()
    }

    @Test("パスワード変更完了時は編集画面を閉じて成功通知を出す")
    @MainActor
    func changePasswordSuccessShowsCompletion() async {
        var initial = makeState()
        initial.destination = .changePassword(.init())
        let store = TestStore(initialState: initial) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.destination(.presented(.changePassword(.received(.success))))) {
            $0.destination = nil
            $0.alert = AlertFeature.success("パスワードが変更されました")
        }
        await store.finish()
    }

    @Test("既存経路の選択は対象IDのUseCaseを呼び出し取得結果を編集画面に渡す")
    @MainActor
    func selectingExistingRouteLoadsDraft() async {
        let route = AppStateFixture.route()
        let period = AppStateFixture.period()
        let pack = RoutePack(route: route, points: [], passages: [])
        let spy = DashboardLoadRouteSpy(result: .success(pack))
        let store = TestStore(initialState: makeState()) {
            DistrictDashboardFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LoadRouteStateUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.onRouteEdit(RouteSlot(period: period, route: route)))
        await store.receive(.routeEditReceived(.success(pack)))
        #expect(await spy.requestedIDs == [route.id])
        #expect(!store.state.isRouteLoading)
        #expect(store.state.destination?.route?.route.id == route.id)
        await store.finish()
    }

    @Test("既存経路の取得エラー時は編集中画面を開かず取得失敗を表示する")
    @MainActor
    func selectingExistingRoutePropagatesError() async {
        let route = AppStateFixture.route()
        let error = AppError.be(.network("offline"))
        let spy = DashboardLoadRouteSpy(result: .failure(error))
        let store = TestStore(initialState: makeState()) {
            DistrictDashboardFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LoadRouteStateUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.onRouteEdit(RouteSlot(period: AppStateFixture.period(), route: route)))
        await store.receive(.routeEditReceived(.failure(error)))
        #expect(await spy.requestedIDs == [route.id])
        #expect(store.state.destination == nil)
        #expect(store.state.alert == .error(error.message))
        #expect(!store.state.isRouteLoading)
        await store.finish()
    }

    @Test("編集に必要なアプリデータがない場合は編集画面を作らずエラーにする")
    @MainActor
    func missingAppStatePreventsDistrictEditing() async {
        let district = AppStateFixture.district()
        let state = DistrictDashboardFeature.State(
            district, appState: Shared(value: nil)
        )
        let store = TestStore(initialState: state) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.onEdit)
        #expect(store.state.destination == nil)
        #expect(store.state.alert == .error("情報の取得に失敗しました"))
        await store.finish()
    }

    @Test("地区設定ボタンは祭典候補と現在の選択状態をUseCaseから取得する")
    @MainActor
    func settingsButtonFetchesDistrictContext() async {
        let festival = AppStateFixture.festival()
        let selection = SceneSelection(festivalId: festival.id, districtId: "district")
        let fetchSpy = DistrictDashboardFetchFestivalsSpy(festivals: [festival])
        let selectionSpy = GetSceneSelectionUseCaseSpy(selection: selection)
        let store = TestStore(initialState: makeState()) {
            DistrictDashboardFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[FetchFestivalListUseCaseKey.self] = fetchSpy
            $0[GetSceneSelectionUseCaseKey.self] = selectionSpy
        }
        store.exhaustivity = .off

        await store.send(.settingsTapped)
        await store.receive(.settingsPrepared(.success(SettingsPreparation(
            festivals: [festival], selection: selection
        ))))
        #expect(await fetchSpy.calls == 1)
        #expect(selectionSpy.callCount == 1)
        #expect(store.state.destination?.settings?.userRole == .district("district"))
        await store.finish()
    }

    @Test("地区管理画面のログアウトはUseCaseを呼び出し成功時に処理中表示を消す")
    @MainActor
    func signOutButtonInvokesUseCase() async {
        let spy = DistrictDashboardSignOutSpy()
        let store = TestStore(initialState: makeState()) {
            DistrictDashboardFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SignOutUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.signOutTapped)
        await store.receive(.signOutReceived(.success(.onboarding)))
        #expect(await spy.calls == 1)
        #expect(!store.state.isAWSLoading)
        await store.finish()
    }


    @Test("既に削除された期間の経路パックは編集画面を開かず取得失敗を表示する")
    @MainActor
    func missingPeriodInRoutePackPreventsEditor() async {
        let route = AppStateFixture.route(periodId: "missing-period")
        let pack = RoutePack(route: route, points: [], passages: [])
        var initial = makeState()
        initial.isRouteLoading = true
        let store = TestStore(initialState: initial) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.routeEditReceived(.success(pack)))
        #expect(!store.state.isRouteLoading)
        #expect(store.state.destination == nil)
        #expect(store.state.alert != nil)
        await store.finish()
    }

    @Test("セッション喪失後は新しい経路の編集画面を開けない")
    @MainActor
    func noSessionBlocksNewRouteEditor() async {
        let initial = DistrictDashboardFeature.State(
            AppStateFixture.district(), appState: Shared(value: nil)
        )
        let store = TestStore(initialState: initial) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.onRouteEdit(RouteSlot(period: AppStateFixture.period(), route: nil)))
        #expect(store.state.destination == nil)
        #expect(store.state.alert != nil)
        await store.finish()
    }

    @Test("位置配信間隔が保存されていなければ標準の1分間隔で設定画面を開く")
    @MainActor
    func locationPreparationWithoutIntervalUsesDefault() async {
        let store = TestStore(initialState: makeState()) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.locationPrepared(
            isTracking: false,
            interval: nil,
            permissionState: .init(
                authorizationStatus: .notDetermined,
                hasRequestedAlwaysLocationPermission: false
            )
        ))
        #expect(store.state.destination?.location?.id == "district")
        #expect(store.state.destination?.location?.selectedInterval == .sample)
        #expect(store.state.destination?.location?.isTracking == false)
        await store.finish()
    }

    @Test("地区編集完了後は編集画面を閉じAppStateにある地区を保持する")
    @MainActor
    func districtEditCompletionClosesEditor() async {
        let store = TestStore(initialState: makeState()) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.onEdit)
        #expect(store.state.destination?.edit != nil)
        await store.send(.destination(.presented(.edit(.postReceived(.success)))))
        #expect(store.state.destination == nil)
        #expect(store.state.district.id == "district")
        await store.finish()
    }

    @Test("画面から戻ったとき共有AppStateに更新された経路一覧を再構築する")
    @MainActor
    func dismissedChildRefreshesRouteSlots() async {
        let appState = Shared<AppState?>(value: AppStateFixture.state())
        let initial = DistrictDashboardFeature.State(
            AppStateFixture.district(), appState: appState
        )
        let store = TestStore(initialState: initial) {
            DistrictDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off
        let route = AppStateFixture.route()

        appState.withLock { $0 = AppStateFixture.state(routes: [route]) }
        await store.send(.destination(.dismiss))
        #expect(store.state.routes.contains { $0.route?.id == route.id })
        await store.finish()
    }
    private func makeState() -> DistrictDashboardFeature.State {
        DistrictDashboardFeature.State(
            AppStateFixture.district(),
            appState: Shared<AppState?>(value: AppStateFixture.state())
        )
    }
}

private actor DashboardLoadRouteSpy: LoadRouteStateUseCaseProtocol {
    let result: Result<RoutePack?, AppError>
    private(set) var requestedIDs: [Route.ID] = []

    init(result: Result<RoutePack?, AppError>) { self.result = result }

    func callAsFunction(routeId: Route.ID, appState: Shared<AppState?>) async throws -> RoutePack? {
        requestedIDs.append(routeId)
        return try result.get()
    }
}

private actor DistrictDashboardFetchFestivalsSpy: FetchFestivalListUseCaseProtocol {
    let festivals: [Festival]
    private(set) var calls = 0

    init(festivals: [Festival]) { self.festivals = festivals }

    func callAsFunction() async throws -> [Festival] {
        calls += 1
        return festivals
    }
}

private actor DistrictDashboardSignOutSpy: SignOutUseCaseProtocol {
    private(set) var calls = 0

    func callAsFunction(appState: Shared<AppState?>) async throws -> LaunchState {
        calls += 1
        return .onboarding
    }
}
