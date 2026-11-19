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
            return nextYearPeriods
        }

        if !currentYearPeriods.isEmpty {
            return currentYearPeriods
        }

        return try await periodRepository.query(by: festivalId, year: nowYear - 1)
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
        guard let year = periods.first?.date.year else { return ([], periods) }
        let routes = try await routeRepository.query(by: districtId, year: year)
        return (routes, periods)
    }
}
