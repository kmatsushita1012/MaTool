import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct DeletePeriodUseCaseTests {
    @Test("削除API成功後は期間と選択中の関連ルートを消去する")
    func deletesPeriodAndOrphanRoutes() async throws {
        let route = AppStateFixture.route()
        let appState = Shared<AppState?>(value: AppStateFixture.state(
            routes: [route], currentRouteId: route.id
        ))
        let spy = PeriodDataFetcherSpy(response: AppStateFixture.period())
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = spy
        } operation: {
            DeletePeriodUseCase()
        }

        try await useCase(id: "period", appState: appState)

        #expect(await spy.recordedCalls() == ["delete:period"])
        #expect(appState.wrappedValue?.festivalState.periods.isEmpty == true)
        #expect(appState.wrappedValue?.districtState?.routes.isEmpty == true)
        #expect(appState.wrappedValue?.routeState == nil)
    }

    @Test("API失敗時は期間を消してはいけない")
    func errorPreservesState() async {
        let original = AppStateFixture.state()
        let appState = Shared<AppState?>(value: original)
        let spy = PeriodDataFetcherSpy(response: AppStateFixture.period(), shouldFail: true)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = spy
        } operation: {
            DeletePeriodUseCase()
        }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(id: "period", appState: appState)
        }
        #expect(appState.wrappedValue == original)
    }

    @Test("セッション破棄済みならリモート削除だけ実施する")
    func nilSessionKeepsStateNil() async throws {
        let appState = Shared<AppState?>(value: nil)
        let spy = PeriodDataFetcherSpy(response: AppStateFixture.period())
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = spy
        } operation: {
            DeletePeriodUseCase()
        }

        try await useCase(id: "period", appState: appState)
        #expect(appState.wrappedValue == nil)
        #expect(await spy.recordedCalls() == ["delete:period"])
    }
}
