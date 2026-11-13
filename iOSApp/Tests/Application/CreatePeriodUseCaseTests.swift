import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct CreatePeriodUseCaseTests {
    @Test("保存APIのレスポンスのみをAppStateに採用する")
    func insertsServerResult() async throws {
        let submitted = AppStateFixture.period(id: "temporary", day: 4)
        var returned = AppStateFixture.period(id: "server-id", day: 4)
        returned.title = "normalized"
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let spy = PeriodDataFetcherSpy(response: returned)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = spy
        } operation: {
            CreatePeriodUseCase()
        }

        let actual = try await useCase(submitted, appState: state)

        #expect(actual == returned)
        #expect(state.wrappedValue?.festivalState.periods.map(\.id) == ["period", "server-id"])
        #expect(state.wrappedValue?.festivalState.periods.last?.title == "normalized")
        #expect(await spy.recordedCalls() == ["create:temporary"])
    }

    @Test("APIが失敗した場合は既存状態を書き換えない")
    func failureDoesNotMutateState() async {
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let spy = PeriodDataFetcherSpy(response: AppStateFixture.period(), shouldFail: true)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = spy
        } operation: {
            CreatePeriodUseCase()
        }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(AppStateFixture.period(id: "new"), appState: state)
        }
        #expect(state.wrappedValue == original)
    }

    @Test("起動セッションが存在しないときはAPIの結果だけ返して状態を作らない")
    func nilSessionDoesNotCreateState() async throws {
        let period = AppStateFixture.period()
        let state = Shared<AppState?>(value: nil)
        let spy = PeriodDataFetcherSpy(response: period)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = spy
        } operation: {
            CreatePeriodUseCase()
        }

        #expect(try await useCase(period, appState: state) == period)
        #expect(state.wrappedValue == nil)
    }
}
