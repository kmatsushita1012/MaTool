import Dependencies
import Shared
import Testing
@testable import iOSApp

struct FetchFestivalPeriodsUseCaseTests {
    @Test("取得した期間一覧は日時の昇順に並べる")
    func sortsFetchedPeriodsByDate() async throws {
        let earlier = AppStateFixture.period(id: "earlier", day: 1)
        let later = AppStateFixture.period(id: "later", day: 3)
        let spy = PeriodDataFetcherSpy(response: earlier, list: [later, earlier])
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = spy
        } operation: {
            FetchFestivalPeriodsUseCase()
        }

        let periods = try await useCase(festivalId: "festival")

        #expect(periods.map(\.id) == ["earlier", "later"])
        #expect(await spy.recordedCalls() == ["fetchAll:festival:all"])
    }

    @Test("空の期間一覧は空のままで返す")
    func emptyList() async throws {
        let spy = PeriodDataFetcherSpy(response: AppStateFixture.period(), list: [])
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = spy
        } operation: {
            FetchFestivalPeriodsUseCase()
        }

        #expect(try await useCase(festivalId: "festival").isEmpty)
        #expect(await spy.recordedCalls().count == 1)
    }

    @Test("取得に失敗したらエラーを伝播する")
    func propagatesError() async {
        let spy = PeriodDataFetcherSpy(response: AppStateFixture.period(), shouldFail: true)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[PeriodDataFetcherKey.self] = spy
        } operation: {
            FetchFestivalPeriodsUseCase()
        }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(festivalId: "festival")
        }
    }
}
