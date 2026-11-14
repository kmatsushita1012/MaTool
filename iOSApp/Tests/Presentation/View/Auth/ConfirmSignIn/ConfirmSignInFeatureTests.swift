import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct ConfirmSignInFeatureTests {
    @Test("確認パスワードが違う場合は送信せずエラー表示する")
    @MainActor
    func rejectsNonmatchingPassword() async {
        var state = ConfirmSignInFeature.State()
        state.password1 = "ValidPass123"
        state.password2 = "AnotherPass123"
        let store = TestStore(initialState: state) {
            ConfirmSignInFeature()
        } withDependencies: {
            $0.installTestSpies()
        }

        await store.send(.submitTapped) {
            $0.alert = AlertFeature.error("パスワードが一致しません。")
        }
        await store.finish()
    }

    @Test("ポリシーに違反するパスワードを認証しない")
    @MainActor
    func rejectsInvalidPassword() async {
        var state = ConfirmSignInFeature.State()
        state.password1 = "short"
        state.password2 = "short"
        let store = TestStore(initialState: state) {
            ConfirmSignInFeature()
        } withDependencies: {
            $0.installTestSpies()
        }

        await store.send(.submitTapped) {
            $0.alert = AlertFeature.error("パスワードが条件を満たしていません。次の条件を満たしてください。\n 8文字以上 \n 少なくとも 1 つの数字を含む \n 少なくとも 1 つの大文字を含む \n 少なくとも 1 つの小文字を含む")
        }
        await store.finish()
    }

    @Test("認証成功では読み込みを解除しエラーを表示しない")
    @MainActor
    func successStopsLoading() async {
        var state = ConfirmSignInFeature.State()
        state.isLoading = true
        let store = TestStore(initialState: state) {
            ConfirmSignInFeature()
        } withDependencies: {
            $0.installTestSpies()
        }

        await store.send(.received(.success(.headquarter("festival")))) {
            $0.isLoading = false
        }
        await store.finish()
    }

    @Test("認証失敗では読み込みを解除しエラーの詳細を表示する")
    @MainActor
    func failureStopsLoadingAndShowsError() async {
        var state = ConfirmSignInFeature.State()
        state.isLoading = true
        let store = TestStore(initialState: state) {
            ConfirmSignInFeature()
        } withDependencies: {
            $0.installTestSpies()
        }
        let error = AppError.be(.network("offline"))

        await store.send(.received(.failure(error))) {
            $0.isLoading = false
            $0.alert = AlertFeature.error("送信に失敗しました。\(error.message)")
        }
        await store.finish()
    }
    @Test("パスワード入力のBindingは入力値だけを更新し認証を開始しない")
    @MainActor
    func bindingUpdatesPasswordWithoutSubmitting() async {
        let store = TestStore(initialState: ConfirmSignInFeature.State()) {
            ConfirmSignInFeature()
        } withDependencies: {
            $0.installTestSpies()
        }

        await store.send(.binding(.set(\.password1, "ValidPass123"))) {
            $0.password1 = "ValidPass123"
        }
        await store.send(.binding(.set(\.password2, "ValidPass123"))) {
            $0.password2 = "ValidPass123"
        }
        #expect(store.state.isLoading == false)
        await store.finish()
    }

    @Test("入力エラー後にアラートを閉じると再入力可能な状態に戻る")
    @MainActor
    func alertDismissalClearsValidationError() async {
        var state = ConfirmSignInFeature.State()
        state.password1 = "ValidPass123"
        state.password2 = "Different123"
        let store = TestStore(initialState: state) {
            ConfirmSignInFeature()
        } withDependencies: {
            $0.installTestSpies()
        }

        await store.send(.submitTapped) {
            $0.alert = AlertFeature.error("パスワードが一致しません。")
        }
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
        #expect(store.state.isLoading == false)
        await store.finish()
    }

    @Test("有効なパスワードで確定するとUseCaseに一度だけ渡し、成功時は読み込みを解除する")
    @MainActor
    func submitValidPasswordCallsUseCase() async {
        let spy = ConfirmSignInUseCaseSpy(result: .success(.guest))
        var state = ConfirmSignInFeature.State()
        state.password1 = "ValidPass123"
        state.password2 = "ValidPass123"
        let store = TestStore(initialState: state) {
            ConfirmSignInFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[ConfirmSignInUseCaseKey.self] = spy
        }

        await store.send(.submitTapped) {
            $0.isLoading = true
        }
        await store.receive(.received(.success(.guest))) {
            $0.isLoading = false
        }
        #expect(await spy.passwords == ["ValidPass123"])
        await store.finish()
    }

    @Test("送信UseCaseが失敗した場合は理由を表示し、同じパスワードで再送信できる")
    @MainActor
    func failedSubmissionCanBeRetried() async {
        let failure = AppError.be(.network("offline"))
        let spy = ConfirmSignInUseCaseSpy(result: .failure(failure))
        var state = ConfirmSignInFeature.State()
        state.password1 = "ValidPass123"
        state.password2 = "ValidPass123"
        let store = TestStore(initialState: state) {
            ConfirmSignInFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[ConfirmSignInUseCaseKey.self] = spy
        }

        await store.send(.submitTapped) {
            $0.isLoading = true
        }
        await store.receive(.received(.failure(failure))) {
            $0.isLoading = false
            $0.alert = AlertFeature.error("送信に失敗しました。\(failure.message)")
        }
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
        await store.send(.submitTapped) {
            $0.isLoading = true
        }
        await store.receive(.received(.failure(failure))) {
            $0.isLoading = false
            $0.alert = AlertFeature.error("送信に失敗しました。\(failure.message)")
        }
        #expect(await spy.passwords == ["ValidPass123", "ValidPass123"])
        await store.finish()
    }

    @Test("閉じるボタンは認証を実行せず、dismissアクションを発行する")
    @MainActor
    func dismissDoesNotConfirmPassword() async {
        let spy = ConfirmSignInUseCaseSpy(result: .success(.guest))
        let store = TestStore(initialState: ConfirmSignInFeature.State()) {
            ConfirmSignInFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[ConfirmSignInUseCaseKey.self] = spy
        }

        await store.send(.dismissTapped)
        #expect(await spy.passwords.isEmpty)
        await store.finish()
    }

}
