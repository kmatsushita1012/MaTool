import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct DistrictReissueFeatureTests {
    @Test("メールアドレス未入力では再発行を開始しない")
    @MainActor
    func emptyEmailShowsValidationError() async {
        let state = DistrictReissueFeature.State(
            districtId: "district", appState: Shared(value: Optional(AppStateFixture.state()))
        )
        let store = TestStore(initialState: state) {
            DistrictReissueFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.reissueTapped) {
            $0.alert = AlertFeature.error("メールアドレスを入力してください。")
        }
        #expect(store.state.isLoading == false)
        await store.finish()
    }

    @Test("再発行成功後に読み込み状態が解除される")
    @MainActor
    func successStopsLoading() async {
        var state = DistrictReissueFeature.State(districtId: "district")
        state.isLoading = true
        let store = TestStore(initialState: state) {
            DistrictReissueFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.reissueReceived(.success)) {
            $0.isLoading = false
        }
        await store.finish()
    }

    @Test("再発行失敗時は詳細を示してローディングを解除する")
    @MainActor
    func failurePresentsAlert() async {
        var state = DistrictReissueFeature.State(districtId: "district")
        state.isLoading = true
        let store = TestStore(initialState: state) {
            DistrictReissueFeature()
        } withDependencies: { $0.installTestSpies() }
        let error = AppError.be(.network("offline"))

        await store.send(.reissueReceived(.failure(error))) {
            $0.isLoading = false
            $0.alert = AlertFeature.error(error.message)
        }
        await store.finish()
    }
}
