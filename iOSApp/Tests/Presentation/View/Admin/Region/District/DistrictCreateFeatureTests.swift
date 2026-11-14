import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct DistrictCreateFeatureTests {
    @Test("地区名またはメールアドレスが空なら作成を開始しない")
    @MainActor
    func missingFieldsPreventSubmit() async {
        let appState = Shared<AppState?>(value: AppStateFixture.state())
        let state = DistrictCreateFeature.State(festivalId: "festival", appState: appState)
        let store = TestStore(initialState: state) {
            DistrictCreateFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.createTapped)
        #expect(store.state.isLoading == false)
        #expect(store.state.alert == nil)
        await store.finish()
    }

    @Test("作成失敗時は読み込みを止めて失敗内容を表示する")
    @MainActor
    func failureClearsLoadingAndShowsAlert() async {
        let appState = Shared<AppState?>(value: AppStateFixture.state())
        var state = DistrictCreateFeature.State(festivalId: "festival", appState: appState)
        state.isLoading = true
        let store = TestStore(initialState: state) {
            DistrictCreateFeature()
        } withDependencies: { $0.installTestSpies() }
        let error = AppError.be(.network("offline"))

        await store.send(.createReceived(.failure(error))) {
            $0.isLoading = false
            $0.alert = AlertFeature.error(error.message)
        }
        await store.finish()
    }

    @Test("作成成功後は読み込みフラグを解除する")
    @MainActor
    func successClearsLoading() async {
        let appState = Shared<AppState?>(value: AppStateFixture.state())
        var state = DistrictCreateFeature.State(festivalId: "festival", appState: appState)
        state.isLoading = true
        let store = TestStore(initialState: state) {
            DistrictCreateFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.createReceived(.success)) {
            $0.isLoading = false
        }
        await store.finish()
    }
}
