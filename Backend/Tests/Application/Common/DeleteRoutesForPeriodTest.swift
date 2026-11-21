import Shared
import Testing
@testable import Backend

struct DeleteRoutesForPeriodTest {
    @Test
    func deleteRoutes_削除対象PeriodのRouteと子要素だけ削除する() async throws {
        let festivalId = "festival-1"
        let period = Period.mock(id: "period-delete", festivalId: festivalId)
        let district = District.mock(id: "district-1", festivalId: festivalId)
        let matchingRoute = Route.mock(id: "route-delete", districtId: district.id, periodId: period.id)
        let unrelatedRoute = Route.mock(id: "route-keep", districtId: district.id, periodId: "period-keep")
        let routes = RouteManagementRepositorySpy(queryHandler: { _ in [matchingRoute, unrelatedRoute] })
        let points = PointManagementRepositorySpy()
        let passages = PassageManagementRepositorySpy()

        try await deleteRoutes(
            for: period,
            festivalId: festivalId,
            districtRepository: DistrictManagementRepositorySpy(queryHandler: { _ in [district] }),
            routeRepository: routes,
            pointRepository: points,
            passageRepository: passages
        )

        #expect(routes.deletedIDs == [matchingRoute.id])
        #expect(points.deletedRouteIDs == [matchingRoute.id])
        #expect(passages.deletedRouteIDs == [matchingRoute.id])
    }
}
