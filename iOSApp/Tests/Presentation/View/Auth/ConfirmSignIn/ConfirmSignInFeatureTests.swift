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
}
