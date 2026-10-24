import ComposableArchitecture
import Dependencies
import Shared

protocol FetchRouteHistoryUseCaseProtocol: Sendable {
    func callAsFunction(districtId: District.ID, festivalId: Festival.ID) async throws -> [RouteEntry]
}

struct FetchRouteHistoryUseCase: FetchRouteHistoryUseCaseProtocol {
    @Dependency(PeriodDataFetcherKey.self) private var periodDataFetcher
    @Dependency(RouteDataFetcherKey.self) private var routeDataFetcher

    func callAsFunction(districtId: District.ID, festivalId: Festival.ID) async throws -> [RouteEntry] {
        async let periodsTask = periodDataFetcher.fetchAll(festivalID: festivalId, query: .all)
        async let routesTask = routeDataFetcher.fetchAll(districtID: districtId, query: .all)
        let (periods, routes) = try await (periodsTask, routesTask)
        let periodsById = Dictionary(uniqueKeysWithValues: periods.map { ($0.id, $0) })

        return routes.compactMap { route in
            guard let period = periodsById[route.periodId] else { return nil }
            return RouteEntry(period: period, route: route)
        }
        .sorted {
            if $0.period == $1.period {
                return $0.route.id < $1.route.id
            }
            return $0.period < $1.period
        }
    }
}

enum FetchRouteHistoryUseCaseKey: DependencyKey {
    static let liveValue: any FetchRouteHistoryUseCaseProtocol = FetchRouteHistoryUseCase()
}
