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

}
