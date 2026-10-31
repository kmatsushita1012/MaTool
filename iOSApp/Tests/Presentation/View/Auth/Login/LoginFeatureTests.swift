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
}
