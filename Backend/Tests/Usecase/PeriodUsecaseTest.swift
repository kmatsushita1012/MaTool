import Dependencies
import Shared
import Testing
@testable import Backend

struct PeriodUsecaseTest {
    @Test
    func get_正常() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1")
        let repository = PeriodRepositoryMock(getHandler: { _ in period })
        let subject = make(repository: repository)

        let result = try await subject.get(id: period.id)

        #expect(result == period)
        #expect(repository.getCallCount == 1)
    }

    @Test
    func get_異常_日程未登録() async {
        let subject = make(repository: .init(getHandler: { _ in nil }))

        await #expect(throws: Error.notFound("指定された日程が取得できませんでした。")) {
            _ = try await subject.get(id: "period-missing")
        }
    }

    @Test
    func queryByYear_正常() async throws {
        let periods = [Period.mock(id: "period-1", festivalId: "festival-1", date: .init(year: 2026, month: 2, day: 22))]
        let repository = PeriodRepositoryMock(queryByYearHandler: { _, _ in periods })

        let subject = make(repository: repository)
        let result = try await subject.query(by: "festival-1", year: 2026)

        #expect(result == periods)
        #expect(repository.queryByYearCallCount == 1)
    }

    @Test
    func query_正常() async throws {
        let periods = [Period.mock(id: "period-2", festivalId: "festival-1")]
        let repository = PeriodRepositoryMock(queryHandler: { _ in periods })
        let subject = make(repository: repository)

        let result = try await subject.query(by: "festival-1")

        #expect(result == periods)
        #expect(repository.queryCallCount == 1)
    }

    @Test
    func post_異常_権限不一致() async {
        let period = Period.mock(festivalId: "festival-1")
        let subject = make()

        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            _ = try await subject.post(festivalId: "festival-1", period: period, user: .guest)
        }
    }

    @Test
    func post_正常() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1")
        let repository = PeriodRepositoryMock(postHandler: { $0 })
        let subject = make(repository: repository)

        let result = try await subject.post(festivalId: "festival-1", period: period, user: .headquarter("festival-1"))

        #expect(result == period)
        #expect(repository.postCallCount == 1)
    }

    @Test
    func put_正常() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1")
        let repository = PeriodRepositoryMock(putHandler: { $0 })
        let subject = make(repository: repository)

        let result = try await subject.put(period: period, user: .headquarter("festival-1"))

        #expect(result == period)
        #expect(repository.putCallCount == 1)
    }

    @Test
    func delete_正常() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1", date: .init(year: 2026, month: 2, day: 22), start: .init(hour: 10, minute: 0))
        var lastCalledFestivalId: String?

        let repository = PeriodRepositoryMock(
            getHandler: { _ in period },
            deleteHandler: { festivalId, _, _ in
                lastCalledFestivalId = festivalId
            }
        )
        let subject = make(repository: repository)

        try await subject.delete(id: period.id, user: .headquarter("festival-1"))

        #expect(repository.deleteCallCount == 1)
        #expect(lastCalledFestivalId == "festival-1")
    }

    @Test
    func query_異常_依存エラーを透過() async {
        let subject = make(repository: .init(queryHandler: { _ in throw TestError.intentional }))

        await #expect(throws: TestError.intentional) {
            _ = try await subject.query(by: "festival-1")
        }
    }
}

private extension PeriodUsecaseTest {
    func make(repository: PeriodRepositoryMock = .init()) -> PeriodUsecase {
        withDependencies {
            $0[PeriodRepositoryKey.self] = repository
        } operation: {
            PeriodUsecase()
        }
    }
}
