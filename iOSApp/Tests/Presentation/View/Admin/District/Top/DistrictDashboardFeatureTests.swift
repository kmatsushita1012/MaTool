import ComposableArchitecture
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

    private func makeState() -> DistrictDashboardFeature.State {
        DistrictDashboardFeature.State(
            AppStateFixture.district(),
            appState: Shared<AppState?>(value: AppStateFixture.state())
        )
    }
}
