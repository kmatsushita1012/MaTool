import Shared
import Testing
@testable import Backend

struct LatestPeriodRouteResolverTest {
    @Test
    func fetchLatestPeriods_翌年Periodありは翌年と今年を返す() async throws {
        let festivalId = "festival-1"
        let repository = PeriodRepositoryMock(queryByYearHandler: { _, year in
            switch year {
            case 2027:
                return [makePeriod(id: "period-2027", festivalId: festivalId, year: 2027)]
            case 2026:
                return [makePeriod(id: "period-2026", festivalId: festivalId, year: 2026)]
            default:
                return []
            }
        })

        let periods = try await LatestPeriodRouteResolver.fetchLatestPeriods(
            festivalId: festivalId,
            nowYear: 2026,
            periodRepository: repository
        )

        #expect(periods.map { $0.id } == ["period-2027", "period-2026"])
        #expect(repository.queryByYearCallCount == 2)
    }

    @Test
    func fetchLatestPeriods_翌年Periodなしは今年と前年を返す() async throws {
        let festivalId = "festival-1"
        let repository = PeriodRepositoryMock(queryByYearHandler: { _, year in
            switch year {
            case 2026:
                return [makePeriod(id: "period-2026", festivalId: festivalId, year: 2026)]
            case 2025:
                return [makePeriod(id: "period-2025", festivalId: festivalId, year: 2025)]
            default:
                return []
            }
        })

        let periods = try await LatestPeriodRouteResolver.fetchLatestPeriods(
            festivalId: festivalId,
            nowYear: 2026,
            periodRepository: repository
        )

        #expect(periods.map { $0.id } == ["period-2026", "period-2025"])
        #expect(repository.queryByYearCallCount == 3)
    }

    @Test
    func fetchLatestRoutes_翌年Periodあり翌年Routeありは翌年を返す() async throws {
        let festivalId = "festival-1"
        let districtId = "district-1"
        let nextYearRoute = Route.mock(id: "route-2027", districtId: districtId)
        var queriedYears: [Int] = []

        let periodRepository = PeriodRepositoryMock(queryByYearHandler: { _, year in
            switch year {
            case 2027:
                return [makePeriod(id: "period-2027", festivalId: festivalId, year: 2027)]
            case 2026:
                return [makePeriod(id: "period-2026", festivalId: festivalId, year: 2026)]
            default:
                return []
            }
        })
        let routeRepository = RouteRepositoryMock(queryByYearHandler: { _, year in
            queriedYears.append(year)
            if year == 2027 { return [nextYearRoute] }
            return []
        })

        let result = try await LatestPeriodRouteResolver.fetchLatestRoutes(
            districtId: districtId,
            festivalId: festivalId,
            nowYear: 2026,
            periodRepository: periodRepository,
            routeRepository: routeRepository
        )

        #expect(result.routes == [nextYearRoute])
        #expect(result.periods.map { $0.id } == ["period-2027", "period-2026"])
        #expect(queriedYears == [2027])
    }

    @Test
    func fetchLatestRoutes_翌年Periodあり翌年Routeなしは今年を返す() async throws {
        let festivalId = "festival-1"
        let districtId = "district-1"
        let currentYearRoute = Route.mock(id: "route-2026", districtId: districtId)
        var queriedYears: [Int] = []

        let periodRepository = PeriodRepositoryMock(queryByYearHandler: { _, year in
            switch year {
            case 2027:
                return [makePeriod(id: "period-2027", festivalId: festivalId, year: 2027)]
            case 2026:
                return [makePeriod(id: "period-2026", festivalId: festivalId, year: 2026)]
            default:
                return []
            }
        })
        let routeRepository = RouteRepositoryMock(queryByYearHandler: { _, year in
            queriedYears.append(year)
            if year == 2026 { return [currentYearRoute] }
            return []
        })

        let result = try await LatestPeriodRouteResolver.fetchLatestRoutes(
            districtId: districtId,
            festivalId: festivalId,
            nowYear: 2026,
            periodRepository: periodRepository,
            routeRepository: routeRepository
        )

        #expect(result.routes == [currentYearRoute])
        #expect(queriedYears == [2027, 2026])
    }

    @Test
    func fetchLatestRoutes_翌年Periodなし今年Routeなしで前年を返す() async throws {
        let festivalId = "festival-1"
        let districtId = "district-1"
        let lastYearRoute = Route.mock(id: "route-2025", districtId: districtId)
        var queriedYears: [Int] = []

        let periodRepository = PeriodRepositoryMock(queryByYearHandler: { _, year in
            switch year {
            case 2026:
                return [makePeriod(id: "period-2026", festivalId: festivalId, year: 2026)]
            case 2025:
                return [makePeriod(id: "period-2025", festivalId: festivalId, year: 2025)]
            default:
                return []
            }
        })
        let routeRepository = RouteRepositoryMock(queryByYearHandler: { _, year in
            queriedYears.append(year)
            if year == 2025 { return [lastYearRoute] }
            return []
        })

        let result = try await LatestPeriodRouteResolver.fetchLatestRoutes(
            districtId: districtId,
            festivalId: festivalId,
            nowYear: 2026,
            periodRepository: periodRepository,
            routeRepository: routeRepository
        )

        #expect(result.routes == [lastYearRoute])
        #expect(queriedYears == [2026, 2025])
    }

    @Test
    func fetchLatestRoutes_PeriodなしはRoute問い合わせなしで空() async throws {
        let periodRepository = PeriodRepositoryMock(queryByYearHandler: { _, _ in [] })
        let routeRepository = RouteRepositoryMock(queryByYearHandler: { _, _ in
            Issue.record("route query should not run when no candidate period exists")
            return []
        })

        let result = try await LatestPeriodRouteResolver.fetchLatestRoutes(
            districtId: "district-1",
            festivalId: "festival-1",
            nowYear: 2026,
            periodRepository: periodRepository,
            routeRepository: routeRepository
        )

        #expect(result.routes.isEmpty)
        #expect(result.periods.isEmpty)
        #expect(routeRepository.queryByYearCallCount == 0)
    }

    @Test
    func fetchLatestRoutes_同一年Period複数でもRoute問い合わせは1回() async throws {
        let festivalId = "festival-1"
        let districtId = "district-1"
        var queriedYears: [Int] = []

        let periodRepository = PeriodRepositoryMock(queryByYearHandler: { _, year in
            switch year {
            case 2027:
                return [
                    makePeriod(id: "period-2027-a", festivalId: festivalId, year: 2027),
                    makePeriod(id: "period-2027-b", festivalId: festivalId, year: 2027)
                ]
            default:
                return []
            }
        })
        let routeRepository = RouteRepositoryMock(queryByYearHandler: { _, year in
            queriedYears.append(year)
            return []
        })

        _ = try await LatestPeriodRouteResolver.fetchLatestRoutes(
            districtId: districtId,
            festivalId: festivalId,
            nowYear: 2026,
            periodRepository: periodRepository,
            routeRepository: routeRepository
        )

        #expect(queriedYears == [2027])
        #expect(routeRepository.queryByYearCallCount == 1)
    }
}

private func makePeriod(id: String, festivalId: String, year: Int) -> Period {
    .mock(
        id: id,
        festivalId: festivalId,
        date: .init(year: year, month: 1, day: 1),
        start: .init(hour: 9, minute: 0),
        end: .init(hour: 10, minute: 0)
    )
}
