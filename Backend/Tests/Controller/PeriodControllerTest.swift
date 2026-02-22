import Dependencies
import Shared
import Testing
@testable import Backend

struct PeriodControllerTest {
    @Test
    func get_forwardsPeriodId() async throws {
        let expected = Period.mock(id: "period-1", festivalId: "festival-1")
        var capturedId: String?
        let mock = PeriodUsecaseMock(getHandler: { id in
            capturedId = id
            return expected
        })
        let subject = make(usecase: mock)

        let request = Application.Request.make(method: .get, path: "/periods/period-1", parameters: ["periodId": "period-1"])
        let response = try await subject.get(request: request, next: next)
        let actual = try Period.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == expected)
        #expect(capturedId == "period-1")
    }

    @Test
    func query_withYear_usesYearSpecificUsecaseMethod() async throws {
        let periods = [Period.mock(id: "period-1", festivalId: "festival-1")]
        var capturedFestivalId: String?
        var capturedYear: Int?

        let mock = PeriodUsecaseMock(
            queryByYearHandler: { festivalId, year in
                capturedFestivalId = festivalId
                capturedYear = year
                return periods
            },
            queryHandler: { _ in [] }
        )
        let subject = make(usecase: mock)

        let request = Application.Request.make(
            method: .get,
            path: "/festivals/festival-1/periods/2026",
            parameters: ["festivalId": "festival-1", "year": "2026"]
        )

        let response = try await subject.query(request: request, next: next)
        let actual = try [Period].from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == periods)
        #expect(capturedFestivalId == "festival-1")
        #expect(capturedYear == 2026)
        #expect(mock.queryByYearCallCount == 1)
        #expect(mock.queryCallCount == 0)
    }

    @Test
    func query_withoutYear_usesDefaultQuery() async throws {
        let periods = [Period.mock(id: "period-1", festivalId: "festival-1")]
        let mock = PeriodUsecaseMock(queryHandler: { _ in periods })
        let subject = make(usecase: mock)

        let request = Application.Request.make(
            method: .get,
            path: "/festivals/festival-1/periods",
            parameters: ["festivalId": "festival-1"]
        )

        let response = try await subject.query(request: request, next: next)
        let actual = try [Period].from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == periods)
        #expect(mock.queryCallCount == 1)
    }

    @Test
    func post_decodesBodyAndForwardsFestivalId() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1")
        var capturedFestivalId: String?
        let mock = PeriodUsecaseMock(postHandler: { festivalId, item, _ in
            capturedFestivalId = festivalId
            return item
        })
        let subject = make(usecase: mock)

        let request = Application.Request.make(
            method: .post,
            path: "/festivals/festival-1/periods",
            parameters: ["festivalId": "festival-1"],
            body: try period.toString()
        )

        let response = try await subject.post(request: request, next: next)
        let actual = try Period.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == period)
        #expect(capturedFestivalId == "festival-1")
    }

    @Test
    func put_decodesBodyAndForwards() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1")
        var capturedPeriod: Period?
        let mock = PeriodUsecaseMock(putHandler: { item, _ in
            capturedPeriod = item
            return item
        })
        let subject = make(usecase: mock)

        let request = Application.Request.make(
            method: .put,
            path: "/periods/period-1",
            parameters: ["periodId": "period-1"],
            body: try period.toString()
        )
        let response = try await subject.put(request: request, next: next)
        let actual = try Period.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == period)
        #expect(capturedPeriod == period)
        #expect(mock.putCallCount == 1)
    }

    @Test
    func delete_forwardsPeriodId() async throws {
        var capturedId: String?
        let mock = PeriodUsecaseMock(deleteHandler: { id, _ in capturedId = id })
        let subject = make(usecase: mock)

        let request = Application.Request.make(method: .delete, path: "/periods/period-1", parameters: ["periodId": "period-1"])
        let response = try await subject.delete(request: request, next: next)

        #expect(response.statusCode == 200)
        #expect(capturedId == "period-1")
        #expect(mock.deleteCallCount == 1)
    }
}

private extension PeriodControllerTest {
    var next: Handler {
        { _ in throw TestError.intentional }
    }

    func make(usecase: PeriodUsecaseMock) -> PeriodController {
        withDependencies {
            $0[PeriodUsecaseKey.self] = usecase
        } operation: {
            PeriodController()
        }
    }
}
