import Foundation
import Dependencies
import Shared
import Testing
@testable import Backend

struct PeriodQueryRouteTest {
    @Test
    func invalidYear_400で全件取得を呼ばない() async throws {
        let usecase = PeriodUsecaseMock(
            queryByYearHandler: { _, _ in [] },
            queryHandler: { _ in [Period.mock(id: "all-period", festivalId: "festival-1")] }
        )
        let app = make(usecase: usecase)

        let response = await app.handle(.make(
            method: .get,
            path: "/festivals/festival-1/periods",
            parameters: ["year": "abc"]
        ))
        let error = try JSONDecoder().decode(ErrorResponse.self, from: Data(response.body.utf8))

        #expect(response.statusCode == 400)
        #expect(error.message == "yearは整数で指定してください。")
        #expect(error.localizedDescription == "yearは整数で指定してください。")
        #expect(usecase.queryByYearCallCount == 0)
        #expect(usecase.queryCallCount == 0)
    }

    @Test
    func validYear_指定年で取得する() async throws {
        let periods = [Period.mock(id: "period-2026", festivalId: "festival-1")]
        let usecase = PeriodUsecaseMock(
            queryByYearHandler: { festivalId, year in
                #expect(festivalId == "festival-1")
                #expect(year == 2026)
                return periods
            },
            queryHandler: { _ in [] }
        )
        let app = make(usecase: usecase)

        let response = await app.handle(.make(
            method: .get,
            path: "/festivals/festival-1/periods",
            parameters: ["year": "2026"]
        ))
        let actual = try [Period].from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == periods)
        #expect(usecase.queryByYearCallCount == 1)
        #expect(usecase.queryCallCount == 0)
    }

    @Test
    func omittedYear_全件取得を維持する() async throws {
        let periods = [Period.mock(id: "period-1", festivalId: "festival-1")]
        let usecase = PeriodUsecaseMock(
            queryByYearHandler: { _, _ in [] },
            queryHandler: { _ in periods }
        )
        let app = make(usecase: usecase)

        let response = await app.handle(.make(
            method: .get,
            path: "/festivals/festival-1/periods"
        ))
        let actual = try [Period].from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == periods)
        #expect(usecase.queryByYearCallCount == 0)
        #expect(usecase.queryCallCount == 1)
    }
}

private extension PeriodQueryRouteTest {
    func make(usecase: PeriodUsecaseMock) -> Application {
        withDependencies {
            $0[FestivalControllerKey.self] = .init()
            $0[DistrictControllerKey.self] = .init()
            $0[LocationControllerKey.self] = .init()
            $0[SceneControllerKey.self] = .init()
            $0[PeriodUsecaseKey.self] = usecase
        } operation: {
            Application { FestivalRouter() }
        }
    }
}
