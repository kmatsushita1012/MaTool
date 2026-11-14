import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct LoginFeatureTests {
    @Test("ログイン成功時に読み込みを終了する")
    @MainActor
    func signInSuccessClearsLoading() async {
        let userRole = UserRole.headquarter("festival")
        var initialState = LoginFeature.State()
        initialState.isLoading = true
        let store = TestStore(initialState: initialState) {
            LoginFeature()
        } withDependencies: {
            $0.installTestSpies()
        }

        await store.send(.received(.success(.signedIn(userRole)))) {
            $0.isLoading = false
        }
        await store.finish()
    }
    @Test("ログイン失敗では読み込みを終了しエラーを表示する")
    @MainActor
    func signInFailureShowsError() async {
        var state = LoginFeature.State()
        state.isLoading = true
        let store = TestStore(initialState: state) {
            LoginFeature()
        } withDependencies: {
            $0.installTestSpies()
        }
        let error = AppError.be(.network("offline"))

        await store.send(.received(.failure(error))) {
            $0.isLoading = false
            $0.errorMessage = error.message
        }
        await store.finish()
    }

    @Test("ユーザーIDとパスワードの入力だけではログインを開始しない")
    @MainActor
    func bindingChangesCredentialsWithoutSignIn() async {
        let store = TestStore(initialState: LoginFeature.State()) {
            LoginFeature()
        } withDependencies: {
            $0.installTestSpies()
        }

        await store.send(.binding(.set(\.id, "user@example.com"))) {
            $0.id = "user@example.com"
        }
        await store.send(.binding(.set(\.password, "Password123"))) {
            $0.password = "Password123"
        }
        #expect(store.state.isLoading == false)
        await store.finish()
    }

    @Test("ログイン成功時には前回のエラーメッセージを消去する")
    @MainActor
    func successfulSignInClearsPreviousError() async {
        var state = LoginFeature.State()
        state.isLoading = true
        state.errorMessage = "previous failure"
        let store = TestStore(initialState: state) {
            LoginFeature()
        } withDependencies: {
            $0.installTestSpies()
        }

        await store.send(.received(.success(.signedIn(.headquarter("festival"))))) {
            $0.isLoading = false
            $0.errorMessage = nil
        }
        await store.finish()
    }

    @Test("ログインボタンは入力したIDとパスワードをUseCaseに渡し、正常応答で終了する")
    @MainActor
    func signInInvokesUseCaseAndStopsLoading() async {
        let spy = SignInUseCaseSpy(result: .success(.signedIn(.guest)))
        var state = LoginFeature.State(id: "user@example.com")
        state.password = "ValidPass123"
        let store = TestStore(initialState: state) {
            LoginFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SignInUseCaseKey.self] = spy
        }

        await store.send(.signInTapped) {
            $0.isLoading = true
        }
        await store.receive(.received(.success(.signedIn(.guest)))) {
            $0.isLoading = false
        }
        #expect(await spy.calls == [
            SignInUseCaseSpy.Call(username: "user@example.com", password: "ValidPass123")
        ])
        await store.finish()
    }

    @Test("ログイン処理中の連続タップはUseCaseを重複実行しない")
    @MainActor
    func repeatedSignInWhileLoadingIsIgnored() async {
        let spy = SignInUseCaseSpy(result: .success(.signedIn(.guest)))
        var state = LoginFeature.State(id: "user@example.com")
        state.isLoading = true
        state.password = "ValidPass123"
        let store = TestStore(initialState: state) {
            LoginFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SignInUseCaseKey.self] = spy
        }

        await store.send(.signInTapped)
        #expect(await spy.calls.isEmpty)
        await store.finish()
    }

    @Test("パスワード再設定画面への遷移で入力済みのユーザーIDを引き継ぐ")
    @MainActor
    func resetPasswordUsesEnteredUsername() async {
        let store = TestStore(initialState: LoginFeature.State(id: "user@example.com")) {
            LoginFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.resetPasswordTapped) {
            $0.destination = .resetPassword(ResetPasswordFeature.State(username: "user@example.com"))
        }
        await store.finish()
    }

    @Test("初回パスワード変更が必要な応答は確認画面を提示し、過去のエラーを消す")
    @MainActor
    func passwordChangeRequiredPresentsConfirmation() async {
        var state = LoginFeature.State(id: "user@example.com")
        state.isLoading = true
        state.errorMessage = "previous error"
        let store = TestStore(initialState: state) {
            LoginFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.received(.success(.newPasswordRequired))) {
            $0.destination = .confirmSignIn(ConfirmSignInFeature.State())
            $0.isLoading = false
            $0.errorMessage = nil
        }
        await store.finish()
    }

    @Test("ログイン画面を閉じても認証UseCaseを起動しない")
    @MainActor
    func dismissDoesNotSignIn() async {
        let spy = SignInUseCaseSpy(result: .success(.signedIn(.guest)))
        let store = TestStore(initialState: LoginFeature.State()) {
            LoginFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SignInUseCaseKey.self] = spy
        }

        await store.send(.dismissTapped)
        #expect(await spy.calls.isEmpty)
        await store.finish()
    }

    @Test("パスワード再設定の確認完了はログイン画面へ戻し入力中の認証情報を維持する")
    @MainActor
    func completedPasswordResetClosesChild() async {
        var initial = LoginFeature.State(id: "user@example.com")
        initial.password = "old-password"
        initial.destination = .resetPassword(.init(username: initial.id))
        let store = TestStore(initialState: initial) {
            LoginFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.resetPassword(.confirmResetReceived(.success)))))
        #expect(store.state.destination == nil)
        #expect(store.state.id == "user@example.com")
        #expect(store.state.password == "old-password")
        await store.finish()
    }

    @Test("初回パスワード変更完了は確認画面を閉じログイン状態を初期化する")
    @MainActor
    func completedInitialPasswordChangeClearsChildAndError() async {
        var initial = LoginFeature.State(id: "user@example.com")
        initial.isLoading = true
        initial.errorMessage = "old error"
        initial.destination = .confirmSignIn(.init())
        let store = TestStore(initialState: initial) {
            LoginFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.confirmSignIn(
            .received(.success(.headquarter("festival")))
        ))))
        #expect(store.state.destination == nil)
        #expect(!store.state.isLoading)
        #expect(store.state.errorMessage == nil)
        await store.finish()
    }

}
