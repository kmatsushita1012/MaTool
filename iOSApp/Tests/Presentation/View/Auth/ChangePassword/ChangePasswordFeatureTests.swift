import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct ChangePasswordFeatureTests {
    @Test("確認用パスワードが不一致なら依存を呼ばずにエラーを表示する")
    @MainActor
    func rejectsMismatchedPasswords() async {
        var state = ChangePasswordFeature.State()
        state.new1 = "ValidPass123"
        state.new2 = "DifferentPass123"
        let spy = PasswordChangeUseCaseSpy()
        let store = TestStore(initialState: state) {
            ChangePasswordFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[ChangePasswordUseCaseKey.self] = spy
        }

        await store.send(.okTapped) {
            $0.alert = AlertFeature.error("パスワード（確認用）が一致しません")
        }
        #expect(await spy.recordedRequests().isEmpty)
        await store.finish()
    }

    @Test("パスワードポリシーに違反している場合は変更処理を開始しない")
    @MainActor
    func rejectsWeakPasswords() async {
        var state = ChangePasswordFeature.State()
        state.new1 = "short"
        state.new2 = "short"
        let spy = PasswordChangeUseCaseSpy()
        let store = TestStore(initialState: state) {
            ChangePasswordFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[ChangePasswordUseCaseKey.self] = spy
        }

        await store.send(.okTapped) {
            $0.alert = AlertFeature.error("パスワードが条件を満たしていません。次の条件を満たしてください。\n 8文字以上 \n 少なくとも 1 つの数字を含む \n 少なくとも 1 つの大文字を含む \n 少なくとも 1 つの小文字を含む")
        }
        #expect(await spy.recordedRequests().isEmpty)
        await store.finish()
    }

    @Test("有効なパスワードは依存へ渡し、完了後に読み込み状態を解除する")
    @MainActor
    func savesValidPassword() async {
        var state = ChangePasswordFeature.State()
        state.current = "OldPass123"
        state.new1 = "ValidPass123"
        state.new2 = "ValidPass123"
        let spy = PasswordChangeUseCaseSpy()
        let store = TestStore(initialState: state) {
            ChangePasswordFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[ChangePasswordUseCaseKey.self] = spy
        }

        await store.send(.okTapped) {
            $0.isLoading = true
        }
        await store.receive(.received(.success)) {
            $0.isLoading = false
        }
        let requests = await spy.recordedRequests()
        #expect(requests.count == 1)
        #expect(requests.first?.current == "OldPass123")
        #expect(requests.first?.new == "ValidPass123")
        await store.finish()
    }

    @Test("変更結果が失敗した場合は読み込みを解除してエラーを表示する")
    @MainActor
    func failedChangeShowsError() async {
        var state = ChangePasswordFeature.State()
        state.isLoading = true
        let store = TestStore(initialState: state) {
            ChangePasswordFeature()
        } withDependencies: {
            $0.installTestSpies()
        }
        let error = AppError.be(.network("offline"))

        await store.send(.received(.failure(error))) {
            $0.isLoading = false
            $0.alert = AlertFeature.error("変更に失敗しました。\(error.message)")
        }
        await store.finish()
    }


    @Test("入力の変更はバインディングで保持し、表示中のエラーを閉じられる")
    @MainActor
    func bindingAndAlertDismissal() async {
        let store = TestStore(initialState: ChangePasswordFeature.State()) {
            ChangePasswordFeature()
        } withDependencies: {
            $0.installTestSpies()
        }

        await store.send(.binding(.set(\.current, "OldPass123"))) {
            $0.current = "OldPass123"
        }
        await store.send(.okTapped) {
            $0.alert = AlertFeature.error("パスワードが条件を満たしていません。次の条件を満たしてください。\n 8文字以上 \n 少なくとも 1 つの数字を含む \n 少なくとも 1 つの大文字を含む \n 少なくとも 1 つの小文字を含む")
        }
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
        await store.finish()
    }
}
