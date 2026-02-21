import Dependencies
import Shared
import Testing
@testable import Backend

struct PeriodUsecaseTest {
    @Test
    func queryByYear_forwardsToRepository() async throws {
        let periods = [Period.mock(id: "period-1", festivalId: "festival-1", date: .init(year: 2026, month: 2, day: 22))]
        let repository = PeriodRepositoryMock(queryByYearHandler: { _, _ in periods })

        let subject = make(repository: repository)
        let result = try await subject.query(by: "festival-1", year: 2026)

        #expect(result == periods)
        #expect(repository.queryByYearCallCount == 1)
    }

    @Test
    func post_unauthorized_throws() async {
        let period = Period.mock(festivalId: "festival-1")
        let subject = make(repository: .init())

        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            _ = try await subject.post(festivalId: "festival-1", period: period, user: .guest)
        }
    }
}

private extension PeriodUsecaseTest {
    func make(repository: PeriodRepositoryMock) -> PeriodUsecase {
        withDependencies {
            $0[PeriodRepositoryKey.self] = repository
        } operation: {
            PeriodUsecase()
        }
    }
}
