import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct UpdateEmailFeatureTests {
    @Test("メール変更完了では確認ダイアログを提示する")
    @MainActor
    func completedUpdateShowsSuccess() async {
        var state = UpdateEmailFeature.State()
        state.isLoading = true
        let store = TestStore(initialState: state) {
            UpdateEmailFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.updateReceived(.success(.completed))) {
            $0.isLoading = false
            $0.completeAlert = AlertFeature.success("メールアドレスが変更されました")
        }
        await store.finish()
    }

    @Test("確認コードが必要な場合は送り先を保持してコード入力へ遷移する")
    @MainActor
    func verificationRequiredPreservesDestination() async {
        var state = UpdateEmailFeature.State()
        state.isLoading = true
        let store = TestStore(initialState: state) {
            UpdateEmailFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.updateReceived(.success(.verificationRequired(destination: "new@example.com")))) {
            $0.isLoading = false
            $0.step = .enterCode(destination: "new@example.com")
        }
        await store.finish()
    }

    @Test("メール変更失敗時に読み込みを解除してエラー表示する")
    @MainActor
    func updateFailureShowsMessage() async {
        var state = UpdateEmailFeature.State()
        state.isLoading = true
        let store = TestStore(initialState: state) {
            UpdateEmailFeature()
        } withDependencies: { $0.installTestSpies() }
        let error = AppError.be(.network("offline"))

        await store.send(.updateReceived(.failure(error))) {
            $0.isLoading = false
            $0.errorAlert = .error(error.message)
        }
        await store.finish()
    }

    @Test("コード確認成功では完了表示し、失敗ではエラー表示する")
    @MainActor
    func codeConfirmationOutcomes() async {
        var state = UpdateEmailFeature.State()
        state.isLoading = true
        let successStore = TestStore(initialState: state) {
            UpdateEmailFeature()
        } withDependencies: { $0.installTestSpies() }

        await successStore.send(.confirmUpdateReceived(.success)) {
            $0.isLoading = false
            $0.completeAlert = AlertFeature.success("メールアドレスが変更されました")
        }
        await successStore.finish()

        state.isLoading = true
        let failureStore = TestStore(initialState: state) {
            UpdateEmailFeature()
        } withDependencies: { $0.installTestSpies() }
        let error = AppError.be(.network("invalid code"))
        await failureStore.send(.confirmUpdateReceived(.failure(error))) {
            $0.isLoading = false
            $0.errorAlert = .error(error.message)
        }
        await failureStore.finish()
    }
}
