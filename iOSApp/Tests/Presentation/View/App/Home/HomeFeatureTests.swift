import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct HomeFeatureTests {
    @Test("設定準備に失敗した後は読み込みを終了して再試行できる")
    @MainActor
    func 設定準備の失敗後に再試行できる() async {
        let useCase = FailingFestivalListUseCase()
        let error = AppError.be(.network("network"))
        let alertMessage = "設定画面の準備に失敗しました。\n\(error)"
        let store = TestStore(initialState: HomeFeature.State(userRole: .guest)) {
            HomeFeature()
        } withDependencies: {
            $0[FetchFestivalListUseCaseKey.self] = useCase
        }

        await store.send(.settingsTapped) {
            $0.isDestinationLoading = true
        }
        await store.receive(.settingsPrepared(.failure(error))) {
            $0.isDestinationLoading = false
            $0.alert = AlertFeature.error(alertMessage)
        }

        await store.send(.alert(.presented(.okTapped))) {
            $0.alert = nil
        }
        await store.send(.settingsTapped) {
            $0.isDestinationLoading = true
        }
        await store.receive(.settingsPrepared(.failure(error))) {
            $0.isDestinationLoading = false
            $0.alert = AlertFeature.error(alertMessage)
        }

        #expect(await useCase.fetchCallCount() == 2)
    }
}

private actor FailingFestivalListUseCase: FetchFestivalListUseCaseProtocol {
    private var fetchCalls = 0

    func callAsFunction() async throws -> [Festival] {
        fetchCalls += 1
        throw AppError.be(.network("network"))
    }

    func fetchCallCount() -> Int {
        fetchCalls
    }
}
