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
}
