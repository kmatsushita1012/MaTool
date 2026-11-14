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

    private func makeState() -> DistrictDashboardFeature.State {
        DistrictDashboardFeature.State(
            AppStateFixture.district(),
            appState: Shared<AppState?>(value: AppStateFixture.state())
        )
    }
}
