import Shared

enum LatestPeriodRouteResolver {
    static func fetchLatestPeriods(
        festivalId: String,
        nowYear: Int,
        periodRepository: any PeriodRepositoryProtocol
    ) async throws -> [Period] {
        async let nextYearTask = periodRepository.query(by: festivalId, year: nowYear + 1)
        async let currentYearTask = periodRepository.query(by: festivalId, year: nowYear)

        let (nextYearPeriods, currentYearPeriods) = try await (nextYearTask, currentYearTask)

        if !nextYearPeriods.isEmpty {
            return nextYearPeriods + currentYearPeriods
        }

        let lastYearPeriods = try await periodRepository.query(by: festivalId, year: nowYear - 1)
        return currentYearPeriods + lastYearPeriods
    }

    static func fetchLatestRoutes(
        districtId: String,
        festivalId: String,
        nowYear: Int,
        periodRepository: any PeriodRepositoryProtocol,
        routeRepository: any RouteRepositoryProtocol
    ) async throws -> (routes: [Route], periods: [Period]) {
        let periods = try await fetchLatestPeriods(
            festivalId: festivalId,
            nowYear: nowYear,
            periodRepository: periodRepository
        )
        let years = Array(Set(periods.map { $0.date.year })).sorted(by: >)

        for year in years {
            let routes = try await routeRepository.query(by: districtId, year: year)
            if !routes.isEmpty {
                return (routes, periods)
            }
        }

        return ([], periods)
    }
}
