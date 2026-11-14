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
    @Test("メール変更を送信すると入力メールをUseCaseへ渡して認証コード画面に進む")
    @MainActor
    func submitEmailInvokesUseCase() async {
        let destination = "new@example.com"
        let spy = UpdateEmailUseCaseSpy(result: .success(.verificationRequired(destination: destination)))
        var state = UpdateEmailFeature.State()
        state.email = destination
        let store = TestStore(initialState: state) {
            UpdateEmailFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[UpdateEmailUseCaseKey.self] = spy
        }

        await store.send(.enterEmail(.okTapped)) {
            $0.isLoading = true
        }
        await store.receive(.updateReceived(.success(.verificationRequired(destination: destination)))) {
            $0.isLoading = false
            $0.step = .enterCode(destination: destination)
        }
        #expect(await spy.emails == [destination])
        await store.finish()
    }

    @Test("確認コードの再送信では入力中のメールを再びUseCaseへ渡す")
    @MainActor
    func resendEmailInvokesUseCaseAgain() async {
        let spy = UpdateEmailUseCaseSpy(result: .success(.completed))
        var state = UpdateEmailFeature.State()
        state.step = .enterCode(destination: "new@example.com")
        state.email = "new@example.com"
        let store = TestStore(initialState: state) {
            UpdateEmailFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[UpdateEmailUseCaseKey.self] = spy
        }

        await store.send(.resendTapped) {
            $0.isLoading = true
        }
        await store.receive(.updateReceived(.success(.completed))) {
            $0.isLoading = false
            $0.completeAlert = AlertFeature.success("メールアドレスが変更されました")
        }
        #expect(await spy.emails == ["new@example.com"])
        await store.finish()
    }

    @Test("コード認証は入力中の確認コードだけをUseCaseに渡す")
    @MainActor
    func submitVerificationCodeCallsUseCase() async {
        let spy = ConfirmUpdateEmailUseCaseSpy()
        var state = UpdateEmailFeature.State()
        state.step = .enterCode(destination: "new@example.com")
        state.code = "902104"
        let store = TestStore(initialState: state) {
            UpdateEmailFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[ConfirmUpdateEmailUseCaseKey.self] = spy
        }

        await store.send(.enterCode(.okTapped)) {
            $0.isLoading = true
        }
        await store.receive(.confirmUpdateReceived(.success)) {
            $0.isLoading = false
            $0.completeAlert = AlertFeature.success("メールアドレスが変更されました")
        }
        #expect(await spy.codes == ["902104"])
        await store.finish()
    }

    @Test("メール入力のBindingは変更を送信せず入力値だけを更新する")
    @MainActor
    func bindingOnlyChangesEmail() async {
        let spy = UpdateEmailUseCaseSpy(result: .success(.completed))
        let store = TestStore(initialState: UpdateEmailFeature.State()) {
            UpdateEmailFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[UpdateEmailUseCaseKey.self] = spy
        }

        await store.send(.binding(.set(\.email, "new@example.com"))) {
            $0.email = "new@example.com"
        }
        #expect(await spy.emails.isEmpty)
        await store.finish()
    }

    @Test("メール変更失敗のアラートは閉じると再試行可能になる")
    @MainActor
    func errorAlertCanBeDismissed() async {
        let error = AppError.be(.network("offline"))
        let store = TestStore(initialState: UpdateEmailFeature.State()) {
            UpdateEmailFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.updateReceived(.failure(error))) {
            $0.errorAlert = .error(error.message)
        }
        await store.send(.errorAlert(.dismiss)) {
            $0.errorAlert = nil
        }
        await store.finish()
    }

    @Test("メール変更完了の確認は成功通知を閉じて親画面へ戻る")
    @MainActor
    func confirmationAlertClosesFeature() async {
        var state = UpdateEmailFeature.State()
        state.completeAlert = AlertFeature.success("メールアドレスが変更されました")
        let store = TestStore(initialState: state) {
            UpdateEmailFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.completeAlert(.dismiss)) {
            $0.completeAlert = nil
        }
        #expect(store.state.completeAlert == nil)
        await store.finish()
    }

    @Test("メール入力と確認コード入力を閉じても更新APIは呼び出されない")
    @MainActor
    func dismissWithoutSubmitting() async {
        let updateSpy = UpdateEmailUseCaseSpy(result: .success(.completed))
        let confirmSpy = ConfirmUpdateEmailUseCaseSpy()
        for codeStep in [false, true] {
            var state = UpdateEmailFeature.State()
            state.email = "draft@example.com"
            if codeStep { state.step = .enterCode(destination: state.email) }
            let store = TestStore(initialState: state) {
                UpdateEmailFeature()
            } withDependencies: {
                $0.installTestSpies()
                $0[UpdateEmailUseCaseKey.self] = updateSpy
                $0[ConfirmUpdateEmailUseCaseKey.self] = confirmSpy
            }
            let action: UpdateEmailFeature.Action = codeStep
                ? .enterCode(.dismissTapped) : .enterEmail(.dismissTapped)
            await store.send(action)
            #expect(store.state.email == "draft@example.com")
            await store.finish()
        }
        #expect(await updateSpy.emails.isEmpty)
        #expect(await confirmSpy.codes.isEmpty)
    }

}
