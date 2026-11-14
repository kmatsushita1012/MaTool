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

        await store.send(.binding(.set(\.festivalErrorMessaage, "manual error"))) {
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

    @Test("祭典選択を解除しても保存UseCaseを起動しない")
    @MainActor
    func clearingFestivalSelectionDoesNotSave() async {
        var initial = OnboardingFeature.State(
            launchState: Shared(value: LaunchState.onboarding),
            appState: Shared<AppState?>(value: nil)
        )
        initial.selectedFestival = AppStateFixture.festival()
        let store = TestStore(initialState: initial) {
            OnboardingFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.binding(.set(\.selectedFestival, nil))) {
            $0.selectedFestival = nil
        }
        #expect(store.state.isFestivalLoading == false)
        await store.finish()
    }

    @Test("地区選択成功でルート指定がない場合も地区画面へ遷移する")
    @MainActor
    func districtSuccessWithoutRoute() async {
        let launch = Shared<LaunchState>(value: .onboarding)
        var initial = OnboardingFeature.State(
            launchState: launch,
            appState: Shared<AppState?>(value: nil)
        )
        initial.isDistrictLoading = true
        let store = TestStore(initialState: initial) {
            OnboardingFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.districtDidSet(.success(nil))) {
            $0.isDistrictLoading = false
        }
        await store.receive(.delegate(.districtSelected(nil)))
        #expect(launch.wrappedValue == .district(.guest, nil))
        await store.finish()
    }

    @Test("祭典の選択Bindingは選択した祭典IDをUseCaseへ渡し、保存失敗で待機状態を解除する")
    @MainActor
    func festivalSelectionFailurePropagatesFromUseCase() async {
        let error = AppError.be(.network("festival unavailable"))
        let spy = SelectFestivalUseCaseSpy(error: error)
        let festival = AppStateFixture.festival()
        let store = TestStore(initialState: OnboardingFeature.State(
            launchState: Shared(value: .onboarding),
            appState: Shared<AppState?>(value: nil)
        )) { OnboardingFeature() } withDependencies: {
            $0.installTestSpies()
            $0[SelectFestivalUseCaseKey.self] = spy
        }

        await store.send(.binding(.set(\.selectedFestival, festival))) {
            $0.selectedFestival = festival
            $0.isFestivalLoading = true
        }
        await store.receive(.festivalDidSet(.failure(error))) {
            $0.isFestivalLoading = false
        }
        #expect(await spy.festivalIDs == [festival.id])
        await store.finish()
    }

    @Test("選択祭典に属する地区はUseCaseに正しい地区IDを渡す")
    @MainActor
    func matchingDistrictStartsDistrictSelection() async {
        let error = AppError.be(.network("district unavailable"))
        let spy = SelectDistrictUseCaseSpy(error: error)
        let festival = AppStateFixture.festival()
        let district = AppStateFixture.district(id: "valid-district")
        var state = OnboardingFeature.State(
            launchState: Shared(value: .onboarding),
            appState: Shared<AppState?>(value: nil)
        )
        state.selectedFestival = festival
        let store = TestStore(initialState: state) {
            OnboardingFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SelectDistrictUseCaseKey.self] = spy
        }

        await store.send(.districtSelected(district)) {
            $0.isDistrictLoading = true
        }
        await store.receive(.districtDidSet(.failure(error))) {
            $0.isDistrictLoading = false
        }
        #expect(await spy.districtIDs == [district.id])
        await store.finish()
    }

    @Test("祭典選択成功は選択IDをUseCaseに渡してローディングを終了する")
    @MainActor
    func selectedFestivalCallsUseCaseSuccessfully() async {
        let festival = AppStateFixture.festival()
        let spy = OnboardingSuccessSelectFestivalSpy()
        let store = TestStore(initialState: OnboardingFeature.State(
            launchState: Shared(value: .onboarding),
            appState: Shared<AppState?>(value: nil)
        )) { OnboardingFeature() } withDependencies: {
            $0.installTestSpies()
            $0[SelectFestivalUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.binding(.set(\.selectedFestival, festival)))
        await store.receive(.festivalDidSet(.success))
        #expect(await spy.festivalIDs == [festival.id])
        #expect(!store.state.isFestivalLoading)
        await store.finish()
    }

    @Test("地区選択成功時はUseCaseが返したRouteIDで初期表示を決める")
    @MainActor
    func selectedDistrictCallsUseCaseSuccessfully() async {
        let district = AppStateFixture.district()
        let launch = Shared<LaunchState>(value: .onboarding)
        let spy = OnboardingSuccessSelectDistrictSpy(returnedRouteID: "saved-route")
        var initial = OnboardingFeature.State(
            launchState: launch, appState: Shared<AppState?>(value: nil)
        )
        initial.selectedFestival = AppStateFixture.festival()
        let store = TestStore(initialState: initial) {
            OnboardingFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SelectDistrictUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.districtSelected(district))
        await store.receive(.districtDidSet(.success("saved-route")))
        await store.receive(.delegate(.districtSelected("saved-route")))
        #expect(await spy.districtIDs == [district.id])
        #expect(launch.wrappedValue == .district(.guest, "saved-route"))
        await store.finish()
    }

    @Test("アプリ情報から地区候補を取得し未取得時は空配列として扱う")
    func districtCandidatesFollowSelectedFestivalState() {
        let withState = OnboardingFeature.State(
            launchState: Shared(value: .onboarding),
            appState: Shared<AppState?>(value: AppStateFixture.state())
        )
        #expect(withState.districts.map(\.id) == ["district"])

        let withoutState = OnboardingFeature.State(
            launchState: Shared(value: .onboarding),
            appState: Shared<AppState?>(value: nil)
        )
        #expect(withoutState.districts.isEmpty)
    }

}

private actor OnboardingSuccessSelectFestivalSpy: SelectFestivalUseCaseProtocol {
    private(set) var festivalIDs: [Festival.ID] = []

    func callAsFunction(
        festivalId: Festival.ID, appState: Shared<AppState?>?,
        signOutCurrentUser: Bool
    ) async throws -> FestivalSelectionResult {
        festivalIDs.append(festivalId)
        return .unchanged
    }
}

private actor OnboardingSuccessSelectDistrictSpy: SelectDistrictUseCaseProtocol {
    private(set) var districtIDs: [District.ID?] = []
    let returnedRouteID: Route.ID?

    init(returnedRouteID: Route.ID?) { self.returnedRouteID = returnedRouteID }

    func callAsFunction(districtId: District.ID?, appState: Shared<AppState?>?) async throws -> Route.ID? {
        districtIDs.append(districtId)
        return returnedRouteID
    }
}
