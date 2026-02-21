import Dependencies
import Shared
import Testing
@testable import Backend

struct PeriodControllerTest {
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
