import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct FestivalDashboardFeatureTests {
    @Test("API・認証・PDF出力・設定のいずれかを実行中ならローディングを表示する")
    func loadingFlagCoversIndependentOperations() {
        var state = makeState()
        #expect(!state.isLoading)

        state.isApiLoading = true
        #expect(state.isLoading)
        state.isApiLoading = false

        state.isAuthLoading = true
        #expect(state.isLoading)
        state.isAuthLoading = false

        state.isExportLoading = true
        #expect(state.isLoading)
        state.isExportLoading = false

        state.isSettingsLoading = true
        #expect(state.isLoading)
        state.isSettingsLoading = false

        #expect(!state.isLoading)
    }

    @Test("管理者の資格情報変更はパスワードとメールアドレスの画面に分かれる")
    @MainActor
    func credentialsNavigation() async {
        let passwordStore = TestStore(initialState: makeState()) {
            FestivalDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        await passwordStore.send(.changePasswordTapped) {
            $0.destination = .changePassword(ChangePasswordFeature.State())
        }
        await passwordStore.finish()

        let emailStore = TestStore(initialState: makeState()) {
            FestivalDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        await emailStore.send(.updateEmailTapped) {
            $0.destination = .updateEmail(UpdateEmailFeature.State())
        }
        await emailStore.finish()
    }

    @Test("日程一覧の取得失敗ではローディングを止めてエラーの理由を示す")
    @MainActor
    func periodLoadingFailure() async {
        let error = AppError.be(.network("offline"))
        var state = makeState()
        state.isApiLoading = true
        let store = TestStore(initialState: state) {
            FestivalDashboardFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.periodsPrepared(.failure(error))) {
            $0.isApiLoading = false
            $0.alert = AlertFeature.error("日程の取得に失敗しました。\n\(error.message)")
        }
        await store.finish()
    }

    @Test("設定一覧の取得失敗では設定画面へ遷移せずエラーを表示する")
    @MainActor
    func settingsLoadingFailure() async {
        let error = AppError.be(.network("offline"))
        var state = makeState()
        state.isSettingsLoading = true
        let store = TestStore(initialState: state) {
            FestivalDashboardFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.settingsPrepared(.failure(error))) {
            $0.isSettingsLoading = false
            $0.alert = AlertFeature.error("設定画面の準備に失敗しました。\n\(error.message)")
        }
        #expect(store.state.destination == nil)
        await store.finish()
    }

    @Test("ログアウト失敗は通知し、成功ではローディングだけを解除する")
    @MainActor
    func signOutOutcomes() async {
        let error = AppError.be(.network("offline"))
        var state = makeState()
        state.isAuthLoading = true
        let failureStore = TestStore(initialState: state) {
            FestivalDashboardFeature()
        } withDependencies: { $0.installTestSpies() }

        await failureStore.send(.signOutReceived(.failure(error))) {
            $0.isAuthLoading = false
            $0.alert = AlertFeature.error("ログアウトに失敗しました　\(error.message)")
        }
        await failureStore.finish()

        let successStore = TestStore(initialState: state) {
            FestivalDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        await successStore.send(.signOutReceived(.success(.onboarding))) {
            $0.isAuthLoading = false
        }
        await successStore.finish()
    }

    @Test("ユーザー入力のBindingは不要な非同期処理を開始しない")
    @MainActor
    func bindingOnlyChangesState() async {
        let store = TestStore(initialState: makeState()) {
            FestivalDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        await store.send(.binding(.set(\.isExportLoading, true))) {
            $0.isExportLoading = true
        }
        #expect(store.state.isLoading)
        await store.finish()
    }

    private func makeState() -> FestivalDashboardFeature.State {
        FestivalDashboardFeature.State(
            AppStateFixture.festival(),
            appState: Shared<AppState?>(value: AppStateFixture.state())
        )
    }
}
