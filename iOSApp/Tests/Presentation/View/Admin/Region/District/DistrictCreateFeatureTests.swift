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
    @Test("地区名が入力済みでもメールアドレスが空なら送信しない")
    @MainActor
    func missingOnlyEmailStillPreventsSubmission() async {
        var state = DistrictCreateFeature.State(festivalId: "festival")
        state.name = "District"
        let store = TestStore(initialState: state) {
            DistrictCreateFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.createTapped)
        #expect(store.state.isLoading == false)
        await store.finish()
    }

    @Test("入力値のBindingは作成を実行せず、入力文字列を保持する")
    @MainActor
    func bindingDoesNotSubmit() async {
        let store = TestStore(initialState: DistrictCreateFeature.State(festivalId: "festival")) {
            DistrictCreateFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.binding(.set(\.name, "町名"))) {
            $0.name = "町名"
        }
        await store.send(.binding(.set(\.email, "test@example.com"))) {
            $0.email = "test@example.com"
        }
        #expect(store.state.isLoading == false)
        await store.finish()
    }

    @Test("必須項目入力後の作成失敗では送信値を記録し、具体的なエラーを表示する")
    @MainActor
    func createFailurePreservesInputAndReportsReason() async {
        let error = AppError.be(.network("offline"))
        let spy = CreateDistrictUseCaseSpy(result: .failure(error))
        var state = DistrictCreateFeature.State(festivalId: "festival")
        state.name = "新しい町"
        state.email = "new@example.com"
        let store = TestStore(initialState: state) {
            DistrictCreateFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[CreateDistrictUseCaseKey.self] = spy
        }

        await store.send(.createTapped) {
            $0.isLoading = true
        }
        await store.receive(.createReceived(.failure(error))) {
            $0.isLoading = false
            $0.alert = AlertFeature.error(error.message)
        }
        #expect(await spy.calls == [
            CreateDistrictUseCaseSpy.Call(
                name: "新しい町", email: "new@example.com", festivalId: "festival"
            )
        ])
        #expect(store.state.name == "新しい町")
        #expect(store.state.email == "new@example.com")
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
        await store.finish()
    }

    @Test("作成画面をキャンセルするとUseCaseを実行しない")
    @MainActor
    func cancelDoesNotSubmit() async {
        let spy = CreateDistrictUseCaseSpy(result: .failure(.be(.network("unexpected"))))
        let store = TestStore(initialState: DistrictCreateFeature.State(festivalId: "festival")) {
            DistrictCreateFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[CreateDistrictUseCaseKey.self] = spy
        }

        await store.send(.cancelTapped)
        #expect(await spy.calls.isEmpty)
        await store.finish()
    }

}
