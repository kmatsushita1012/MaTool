import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct OnboardingFeatureTests {
    @Test("祭典一覧の成功応答を状態へ反映する")
    @MainActor
    func acceptsFestivalList() async {
        let state = OnboardingFeature.State(
            launchState: Shared(value: LaunchState.loading),
            appState: Shared<AppState?>(value: nil)
        )
        let store = TestStore(initialState: state) {
            OnboardingFeature()
        } withDependencies: { $0.installTestSpies() }
        let festival = AppStateFixture.festival()

        await store.send(.festivalsLoaded(.success([festival]))) {
            $0.festivals = [festival]
        }
        await store.finish()
    }

    @Test("祭典一覧取得失敗ではエラーを表示して状態を保持する")
    @MainActor
    func festivalListFailureDoesNotSelectFestival() async {
        let state = OnboardingFeature.State(
            launchState: Shared(value: LaunchState.loading),
            appState: Shared<AppState?>(value: nil)
        )
        let store = TestStore(initialState: state) {
            OnboardingFeature()
        } withDependencies: { $0.installTestSpies() }
        let error = AppError.be(.network("offline"))

        await store.send(.festivalsLoaded(.failure(error))) {
            $0.festivalErrorMessaage = error.message
        }
        #expect(store.state.selectedFestival == nil)
        await store.finish()
    }

    @Test("祭典未選択でゲスト遷移を要求するとエラーを表示する")
    @MainActor
    func selectingGuestWithoutFestivalIsRejected() async {
        let state = OnboardingFeature.State(
            launchState: Shared(value: LaunchState.loading),
            appState: Shared<AppState?>(value: nil)
        )
        let store = TestStore(initialState: state) {
            OnboardingFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.externalGuestTapped) {
            $0.festivalErrorMessaage = "祭典を選択してください。"
        }
        await store.send(.adminTapped)
        await store.finish()
    }

    @Test("祭典未選択で地区を選択するとエラーを表示する")
    @MainActor
    func districtWithoutSelectedFestivalIsRejected() async {
        let state = OnboardingFeature.State(
            launchState: Shared(value: LaunchState.loading),
            appState: Shared<AppState?>(value: nil)
        )
        let store = TestStore(initialState: state) {
            OnboardingFeature()
        } withDependencies: { $0.installTestSpies() }
        let district = District(id: "district", name: "District", festivalId: "festival")

        await store.send(.districtSelected(district)) {
            $0.festivalErrorMessaage = "祭典を選択してください。"
        }
        await store.finish()
    }

    @Test("選択中の祭典と異なる地区を指定しても遷移しない")
    @MainActor
    func unrelatedDistrictIsRejected() async {
        var state = OnboardingFeature.State(
            launchState: Shared(value: LaunchState.loading),
            appState: Shared<AppState?>(value: nil)
        )
        state.selectedFestival = AppStateFixture.festival()
        let store = TestStore(initialState: state) {
            OnboardingFeature()
        } withDependencies: { $0.installTestSpies() }
        let district = District(id: "foreign", name: "Other", festivalId: "different")

        await store.send(.districtSelected(district)) {
            $0.festivalErrorMessaage = "祭典を選択してください。"
        }
        await store.finish()
    }

    @Test("祭典・地区の保存失敗時はローディングを解除する")
    @MainActor
    func saveFailuresStopLoading() async {
        var state = OnboardingFeature.State(
            launchState: Shared(value: LaunchState.loading),
            appState: Shared<AppState?>(value: nil)
        )
        state.isFestivalLoading = true
        state.isDistrictLoading = true
        let store = TestStore(initialState: state) {
            OnboardingFeature()
        } withDependencies: { $0.installTestSpies() }
        let error = AppError.be(.network("offline"))

        await store.send(.festivalDidSet(.failure(error))) {
            $0.isFestivalLoading = false
        }
        await store.send(.districtDidSet(.failure(error))) {
            $0.isDistrictLoading = false
        }
        await store.finish()
    }
    @Test("表示開始時は祭典一覧の取得UseCaseが呼ばれ一覧が設定される")
    @MainActor
    func onAppearFetchesFestivals() async {
        let festival = AppStateFixture.festival()
        let store = TestStore(initialState: OnboardingFeature.State(
            launchState: Shared(value: .loading),
            appState: Shared<AppState?>(value: nil)
        )) { OnboardingFeature() } withDependencies: {
            $0.installTestSpies()
            $0[FetchFestivalListUseCaseKey.self] = FetchFestivalListUseCaseSpy(festivals: [festival])
        }

        await store.send(.onAppear)
        await store.receive(.festivalsLoaded(.success([festival]))) {
            $0.festivals = [festival]
        }
        await store.finish()
    }

    @Test("選択済み祭典でゲストとして進むと祭典地図画面へ遷移する")
    @MainActor
    func guestWithSelectedFestivalContinuesToMap() async {
        let sharedLaunch = Shared<LaunchState>(value: .onboarding)
        var initial = OnboardingFeature.State(
            launchState: sharedLaunch,
            appState: Shared<AppState?>(value: nil)
        )
        initial.selectedFestival = AppStateFixture.festival()
        let store = TestStore(initialState: initial) {
            OnboardingFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.externalGuestTapped)
        await store.receive(.delegate(.continueAsGuest))

        #expect(sharedLaunch.wrappedValue == .festival(.guest))
        await store.finish()
    }

    @Test("本部ログイン導線も祭典選択後はゲストの地図画面へ進む")
    @MainActor
    func adminWithSelectedFestivalContinuesToMap() async {
        let sharedLaunch = Shared<LaunchState>(value: .onboarding)
        var initial = OnboardingFeature.State(
            launchState: sharedLaunch,
            appState: Shared<AppState?>(value: nil)
        )
        initial.selectedFestival = AppStateFixture.festival()
        let store = TestStore(initialState: initial) {
            OnboardingFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.adminTapped)
        await store.receive(.delegate(.continueAsGuest))

        #expect(sharedLaunch.wrappedValue == .festival(.guest))
        await store.finish()
    }

    @Test("地区選択成功時は現在のRouteIDを引き継いで地区画面へ進む")
    @MainActor
    func districtSuccessSetsInitialRoute() async {
        let sharedLaunch = Shared<LaunchState>(value: .onboarding)
        let appState = Shared<AppState?>(value: AppStateFixture.state())
        var initial = OnboardingFeature.State(
            launchState: sharedLaunch, appState: appState
        )
        initial.selectedFestival = AppStateFixture.festival()
        initial.isDistrictLoading = true
        let store = TestStore(initialState: initial) {
            OnboardingFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.districtDidSet(.success("route"))) {
            $0.isDistrictLoading = false
        }
        await store.receive(.delegate(.districtSelected("route")))

        #expect(sharedLaunch.wrappedValue == .district(.guest, "route"))
        await store.finish()
    }

    @Test("祭典選択保存成功時はロード中状態を解除して一覧を残す")
    @MainActor
    func festivalSuccessClearsLoading() async {
        var initial = OnboardingFeature.State(
            launchState: Shared(value: .onboarding),
            appState: Shared<AppState?>(value: nil)
        )
        initial.isFestivalLoading = true
        initial.festivals = [AppStateFixture.festival()]
        let store = TestStore(initialState: initial) {
            OnboardingFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.festivalDidSet(.success)) {
            $0.isFestivalLoading = false
        }
        #expect(store.state.festivals.count == 1)
        await store.finish()
    }

    @Test("祭典以外のバインディング変更では保存処理を開始しない")
    @MainActor
    func nonFestivalBindingDoesNotStartSelection() async {
        let store = TestStore(initialState: OnboardingFeature.State(
            launchState: Shared(value: .onboarding),
            appState: Shared<AppState?>(value: nil)
        )) { OnboardingFeature() } withDependencies: {
            $0.installTestSpies()
        }

        await store.send(\.binding.festivalErrorMessaage, "manual error") {
            $0.festivalErrorMessaage = "manual error"
        }
        #expect(store.state.isFestivalLoading == false)
        await store.finish()
    }

    @Test("親画面からのdelegateアクションは状態を変更しない")
    @MainActor
    func delegateActionDoesNotMutateState() async {
        let store = TestStore(initialState: OnboardingFeature.State(
            launchState: Shared(value: .onboarding),
            appState: Shared<AppState?>(value: nil)
        )) { OnboardingFeature() } withDependencies: {
            $0.installTestSpies()
        }

        await store.send(.delegate(.continueAsGuest))
        await store.finish()
    }

}
