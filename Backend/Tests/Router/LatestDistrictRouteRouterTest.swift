import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct LatestDistrictRouteRouterTest {
    @Test
    func launchDistrict_ApplicationHandle経由で最新Period年度にRouteがなくても前年Routeを返す() async throws {
        let nowYear = SimpleDate.now.year
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let currentPeriod = Period.mock(
            id: "period-current",
            festivalId: district.festivalId,
            date: .init(year: nowYear, month: 10, day: 3)
        )
        let previousPeriod = Period.mock(
            id: "period-previous",
            festivalId: district.festivalId,
            date: .init(year: nowYear - 1, month: 10, day: 3)
        )
        let previousRoute = Route.mock(
            id: "route-previous",
            districtId: district.id,
            periodId: previousPeriod.id
        )

        let request = Application.Request.make(method: .get, path: "/districts/\(district.id)/launch")
        let response = await withDependencies {
            $0[FestivalControllerKey.self] = FestivalControllerMock()
            $0[DistrictControllerKey.self] = DistrictControllerMock()
            $0[RouteControllerKey.self] = RouteControllerMock()
            $0[LocationControllerKey.self] = LocationControllerMock()
            $0[PeriodControllerKey.self] = PeriodControllerMock()
            $0[DistrictRepositoryKey.self] = .init(getHandler: { _ in district })
            $0[PeriodRepositoryKey.self] = .init(queryByYearHandler: { _, year in
                switch year {
                case nowYear: [currentPeriod]
                case nowYear - 1: [previousPeriod]
                default: []
                }
            })
            $0[RouteRepositoryKey.self] = .init(queryByYearHandler: { _, year in
                year == nowYear - 1 ? [previousRoute] : []
            })
            $0[PerformanceRepositoryKey.self] = .init(queryHandler: { _ in [] })
            $0[PointRepositoryKey.self] = .init(queryHandler: { _ in [] })
            $0[PassageRepositoryKey.self] = .init(queryHandler: { _ in [] })
            $0[SceneControllerKey.self] = SceneController()
            $0[SceneUsecaseKey.self] = SceneUsecase()
        } operation: {
            let app = Application {
                AuthMiddleware(path: "/")
                FestivalRouter()
                DistrictRouter()
                OtherRouter()
            }
            return await app.handle(request)
        }

        #expect(response.statusCode == 200, "response body: \(response.body)")
        guard response.statusCode == 200 else { return }

        #expect(response.headers["Content-Type"] == "application/json")
        let pack = try JSONDecoder().decode(LaunchDistrictPack.self, from: Data(response.body.utf8))
        #expect(pack.routes == [previousRoute])
        #expect(pack.currentRouteId == previousRoute.id)
    }
}
