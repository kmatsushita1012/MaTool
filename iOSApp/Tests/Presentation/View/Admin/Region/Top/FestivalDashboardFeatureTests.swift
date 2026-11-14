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

    @Test("祭典編集と町一覧はそれぞれ専用の画面Stateを開く")
    @MainActor
    func festivalAndDistrictNavigation() async {
        let editing = TestStore(initialState: makeState()) {
            FestivalDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        editing.exhaustivity = .off
        await editing.send(.onEdit)
        #expect(editing.state.destination?.edit?.festival.id == "festival")
        await editing.finish()

        let listing = TestStore(initialState: makeState()) {
            FestivalDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        listing.exhaustivity = .off
        await listing.send(.districtsTapped)
        #expect(listing.state.destination?.districts != nil)
        await listing.finish()
    }

    @Test("取得した日程は編集一覧へ渡し、ロード中表示を消す")
    @MainActor
    func fetchedPeriodsOpenPeriodList() async {
        var initial = makeState()
        initial.isApiLoading = true
        let store = TestStore(initialState: initial) {
            FestivalDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off
        let periods = [AppStateFixture.period(id: "morning"), AppStateFixture.period(id: "evening")]

        await store.send(.periodsPrepared(.success(periods)))
        #expect(!store.state.isApiLoading)
        #expect(store.state.destination?.periods?.festivalId == "festival")
        #expect(store.state.destination?.periods?.periods.count == 2)
        await store.finish()
    }

    @Test("設定情報が揃うと本部管理者権限で設定画面を開く")
    @MainActor
    func fetchedSettingsOpenHeadquarterSettings() async {
        var initial = makeState()
        initial.isSettingsLoading = true
        let store = TestStore(initialState: initial) {
            FestivalDashboardFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.settingsPrepared(.success(.init(
            festivals: [AppStateFixture.festival()],
            selection: SceneSelection(festivalId: "festival", districtId: nil)
        ))))
        #expect(!store.state.isSettingsLoading)
        #expect(store.state.destination?.settings?.userRole == .headquarter("festival"))
        await store.finish()
    }

    @Test("パスワード変更完了を受け取ったら編集画面を閉じ成功通知を出す")
    @MainActor
    func successfulPasswordChangeShowsNotice() async {
        var initial = makeState()
        initial.destination = .changePassword(.init())
        let store = TestStore(initialState: initial) {
            FestivalDashboardFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.destination(.presented(.changePassword(.received(.success))))) {
            $0.destination = nil
            $0.alert = AlertFeature.success("パスワードが変更されました")
        }
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
        await store.finish()
    }

    @Test("日程ボタンは祭典IDでUseCaseを呼び出し取得した日程へ遷移する")
    @MainActor
    func periodTappedFetchesFestivalPeriods() async {
        let periods = [AppStateFixture.period(id: "first")]
        let spy = DashboardFetchPeriodsSpy(result: .success(periods))
        let store = TestStore(initialState: makeState()) {
            FestivalDashboardFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[FetchFestivalPeriodsUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.periodTapped)
        await store.receive(.periodsPrepared(.success(periods)))
        #expect(await spy.requestedFestivalIDs == ["festival"])
        #expect(store.state.destination?.periods?.periods == periods)
        #expect(!store.state.isApiLoading)
        await store.finish()
    }

    @Test("日程の取得エラーが発生した場合は画面遷移せずエラーを通知する")
    @MainActor
    func periodTappedPropagatesFetchFailure() async {
        let error = AppError.be(.network("offline"))
        let spy = DashboardFetchPeriodsSpy(result: .failure(error))
        let store = TestStore(initialState: makeState()) {
            FestivalDashboardFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[FetchFestivalPeriodsUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.periodTapped)
        await store.receive(.periodsPrepared(.failure(error)))
        #expect(await spy.requestedFestivalIDs == ["festival"])
        #expect(!store.state.isApiLoading)
        #expect(store.state.destination == nil)
        #expect(store.state.alert == .error("日程の取得に失敗しました。\n\(error.message)"))
        await store.finish()
    }

    @Test("設定ボタンは祭典一覧と保存済みシーンを取得して設定画面を作る")
    @MainActor
    func settingsTappedFetchesPreparationValues() async {
        let festival = AppStateFixture.festival()
        let selection = SceneSelection(festivalId: festival.id, districtId: nil)
        let festivalSpy = DashboardFetchFestivalsSpy(result: .success([festival]))
        let sceneSpy = GetSceneSelectionUseCaseSpy(selection: selection)
        let store = TestStore(initialState: makeState()) {
            FestivalDashboardFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[FetchFestivalListUseCaseKey.self] = festivalSpy
            $0[GetSceneSelectionUseCaseKey.self] = sceneSpy
        }
        store.exhaustivity = .off

        await store.send(.settingsTapped)
        await store.receive(.settingsPrepared(.success(SettingsPreparation(
            festivals: [festival], selection: selection
        ))))
        #expect(await festivalSpy.calls == 1)
        #expect(sceneSpy.callCount == 1)
        #expect(store.state.destination?.settings?.userRole == .headquarter("festival"))
        await store.finish()
    }

    @Test("本部管理画面でログアウト操作するとUseCaseへ委譲し処理中表示を解除する")
    @MainActor
    func signOutTappedDelegatesToUseCase() async {
        let spy = FestivalDashboardSignOutSpy()
        let store = TestStore(initialState: makeState()) {
            FestivalDashboardFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SignOutUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.signOutTapped)
        await store.receive(.signOutReceived(.success(.onboarding)))
        #expect(await spy.calls == 1)
        #expect(!store.state.isAuthLoading)
        await store.finish()
    }

    private func makeState() -> FestivalDashboardFeature.State {
        FestivalDashboardFeature.State(
            AppStateFixture.festival(),
            appState: Shared<AppState?>(value: AppStateFixture.state())
        )
    }
}

private actor DashboardFetchPeriodsSpy: FetchFestivalPeriodsUseCaseProtocol {
    let result: Result<[Period], AppError>
    private(set) var requestedFestivalIDs: [Festival.ID] = []

    init(result: Result<[Period], AppError>) { self.result = result }

    func callAsFunction(festivalId: Festival.ID) async throws -> [Period] {
        requestedFestivalIDs.append(festivalId)
        return try result.get()
    }
}

private actor DashboardFetchFestivalsSpy: FetchFestivalListUseCaseProtocol {
    let result: Result<[Festival], AppError>
    private(set) var calls = 0

    init(result: Result<[Festival], AppError>) { self.result = result }

    func callAsFunction() async throws -> [Festival] {
        calls += 1
        return try result.get()
    }
}

private actor FestivalDashboardSignOutSpy: SignOutUseCaseProtocol {
    private(set) var calls = 0

    func callAsFunction(appState: Shared<AppState?>) async throws -> LaunchState {
        calls += 1
        return .onboarding
    }
}
