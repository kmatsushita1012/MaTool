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
    @Test("メールアドレスBindingは再発行せず入力値だけを保持する")
    @MainActor
    func bindingDoesNotIssue() async {
        let store = TestStore(initialState: DistrictReissueFeature.State(districtId: "district")) {
            DistrictReissueFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.binding(.set(\.email, "new@example.com"))) {
            $0.email = "new@example.com"
        }
        #expect(store.state.isLoading == false)
        await store.finish()
    }

    @Test("入力済みメールで再発行すると対象IDをUseCaseへ渡し、異常時にエラーを示す")
    @MainActor
    func reissueFailureRecordsRequest() async {
        let error = AppError.be(.network("offline"))
        let spy = ReissueDistrictUseCaseSpy(result: .failure(error))
        var state = DistrictReissueFeature.State(districtId: "district")
        state.email = "new@example.com"
        let store = TestStore(initialState: state) {
            DistrictReissueFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[ReissueDistrictUseCaseKey.self] = spy
        }

        await store.send(.reissueTapped) {
            $0.isLoading = true
        }
        await store.receive(.reissueReceived(.failure(error))) {
            $0.isLoading = false
            $0.alert = AlertFeature.error(error.message)
        }
        #expect(await spy.calls == [
            ReissueDistrictUseCaseSpy.Call(districtId: "district", email: "new@example.com")
        ])
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
        await store.finish()
    }

    @Test("キャンセルでは再発行リクエストが発生しない")
    @MainActor
    func cancelDoesNotIssue() async {
        let spy = ReissueDistrictUseCaseSpy(result: .failure(.be(.network("unexpected"))))
        let store = TestStore(initialState: DistrictReissueFeature.State(districtId: "district")) {
            DistrictReissueFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[ReissueDistrictUseCaseKey.self] = spy
        }

        await store.send(.cancelTapped)
        #expect(await spy.calls.isEmpty)
        await store.finish()
    }

}
