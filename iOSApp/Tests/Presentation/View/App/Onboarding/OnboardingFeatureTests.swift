import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct OnboardingFeatureTests {
    @Test("祭典未選択でゲスト継続を要求すると選択エラーを表示する")
    @MainActor
    func guestWithoutFestivalShowsError() async {
        let store = makeStore()
        await store.send(.externalGuestTapped) {
            $0.festivalErrorMessaage = "祭典を選択してください。"
        }
        await store.finish()
    }

    @Test("祭典未選択で管理者画面へ進もうとすると選択エラーを表示する")
    @MainActor
    func adminWithoutFestivalShowsError() async {
        let store = makeStore()
        await store.send(.adminTapped) {
            $0.festivalErrorMessaage = "祭典を選択してください。"
        }
        await store.finish()
    }

    @Test("祭典一覧の読み込み成功で一覧を更新する")
    @MainActor
    func festivalsLoadedUpdatesList() async {
        let fixture = OnboardingFixture()
        let store = makeStore()
        await store.send(.festivalsLoaded(.success([fixture.festival]))) {
            $0.festivals = [fixture.festival]
        }
        await store.finish()
    }

    @Test("祭典選択なしの地区選択では選択エラーを表示する")
    @MainActor
    func districtWithoutFestivalShowsError() async {
        let fixture = OnboardingFixture()
        let store = makeStore()
        await store.send(.districtSelected(fixture.district)) {
            $0.festivalErrorMessaage = "祭典を選択してください。"
        }
        await store.finish()
    }

    @Test("祭典選択処理の完了で読み込み表示を終了する")
    @MainActor
    func festivalSelectionSuccessClearsLoading() async {
        let store = makeStore(isFestivalLoading: true)
        await store.send(.festivalDidSet(.success(()))) {
            $0.isFestivalLoading = false
        }
        await store.finish()
    }

    @Test("地区選択処理の失敗で読み込み表示を終了する")
    @MainActor
    func districtSelectionFailureClearsLoading() async {
        let store = makeStore(isDistrictLoading: true)
        await store.send(.districtDidSet(.failure(.be(.network("network"))))) {
            $0.isDistrictLoading = false
        }
        await store.finish()
    }

    @MainActor
    private func makeStore(
        isFestivalLoading: Bool = false,
        isDistrictLoading: Bool = false
    ) -> TestStoreOf<OnboardingFeature> {
        var state = OnboardingFeature.State(
            launchState: Shared(value: LaunchState.onboarding),
            appState: Shared(value: Optional<AppState>.none)
        )
        state.isFestivalLoading = isFestivalLoading
        state.isDistrictLoading = isDistrictLoading
        return TestStore(initialState: state) {
            OnboardingFeature()
        } withDependencies: {
            $0.installTestSpies()
        }
    }
}

private struct OnboardingFixture {
    let festival = Festival(
        id: "festival",
        name: "Festival",
        subname: "Festival",
        base: Coordinate(latitude: 35, longitude: 139)
    )
    var district: District {
        District(id: "district", name: "District", festivalId: festival.id)
    }
}
