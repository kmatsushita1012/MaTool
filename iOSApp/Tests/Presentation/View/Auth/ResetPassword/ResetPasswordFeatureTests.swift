import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct ResetPasswordFeatureTests {
    @Test("リセット要求成功後に確認コード入力へ遷移する")
    @MainActor
    func resetMovesToCodeStep() async {
        var state = ResetPasswordFeature.State()
        state.isLoading = true
        let store = TestStore(initialState: state) {
            ResetPasswordFeature()
        } withDependencies: {
            $0.installTestSpies()
        }

        await store.send(.resetReceived(.success)) {
            $0.isLoading = false
            $0.step = .enterCode
        }
        await store.finish()
    }

    @Test("リセット要求失敗時に元の画面で詳細エラーを表示する")
    @MainActor
    func resetFailureShowsError() async {
        var state = ResetPasswordFeature.State()
        state.isLoading = true
        let store = TestStore(initialState: state) {
            ResetPasswordFeature()
        } withDependencies: {
            $0.installTestSpies()
        }
        let error = AppError.be(.network("offline"))

        await store.send(.resetReceived(.failure(error))) {
            $0.isLoading = false
            $0.alert = AlertFeature.error("リセットに失敗しました。\(error.message)")
        }
        await store.finish()
    }

    @Test("確認パスワードが異なる場合はリセットを実行しない")
    @MainActor
    func rejectsMismatchedConfirmation() async {
        var state = ResetPasswordFeature.State()
        state.step = .enterCode
        state.newPassword1 = "ValidPass123"
        state.newPassword2 = "AnotherPass123"
        let store = TestStore(initialState: state) {
            ResetPasswordFeature()
        } withDependencies: {
            $0.installTestSpies()
        }

        await store.send(.enterCode(.okTapped)) {
            $0.alert = AlertFeature.error("パスワード（確認用）が一致しません")
        }
        await store.finish()
    }

    @Test("確認パスワードがポリシー違反の場合もリセットを実行しない")
    @MainActor
    func rejectsWeakConfirmation() async {
        var state = ResetPasswordFeature.State()
        state.step = .enterCode
        state.newPassword1 = "short"
        state.newPassword2 = "short"
        let store = TestStore(initialState: state) {
            ResetPasswordFeature()
        } withDependencies: {
            $0.installTestSpies()
        }

        await store.send(.enterCode(.okTapped)) {
            $0.alert = AlertFeature.error("パスワードが条件を満たしていません。次の条件を満たしてください。\n 8文字以上 \n 少なくとも 1 つの数字を含む \n 少なくとも 1 つの大文字を含む \n 少なくとも 1 つの小文字を含む")
        }
        await store.finish()
    }

    @Test("確認成功と失敗はいずれも読み込みを解除し、失敗は説明を示す")
    @MainActor
    func confirmationOutcomes() async {
        let error = AppError.be(.network("expired"))
        var successState = ResetPasswordFeature.State()
        successState.isLoading = true
        let successStore = TestStore(initialState: successState) {
            ResetPasswordFeature()
        } withDependencies: { $0.installTestSpies() }

        await successStore.send(.confirmResetReceived(.success)) {
            $0.isLoading = false
        }
        await successStore.finish()

        var failureState = ResetPasswordFeature.State()
        failureState.isLoading = true
        let failureStore = TestStore(initialState: failureState) {
            ResetPasswordFeature()
        } withDependencies: { $0.installTestSpies() }

        await failureStore.send(.confirmResetReceived(.failure(error))) {
            $0.isLoading = false
            $0.alert = AlertFeature.error("リセットに失敗しました。\(error.message)")
        }
        await failureStore.finish()
    }
}
