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

        let app = make(
            districtRepository: .init(getHandler: { _ in district }),
            periodRepository: .init(queryByYearHandler: { _, year in
                switch year {
                case nowYear: [currentPeriod]
                case nowYear - 1: [previousPeriod]
                default: []
                }
            }),
            routeRepository: .init(queryByYearHandler: { _, year in
                year == nowYear - 1 ? [previousRoute] : []
            }),
            performanceRepository: .init(queryHandler: { _ in [] }),
            pointRepository: .init(queryHandler: { _ in [] }),
            passageRepository: .init(queryHandler: { _ in [] })
        )

        let response = await app.handle(.make(method: .get, path: "/districts/\(district.id)/launch"))
        let pack = try JSONDecoder().decode(LaunchDistrictPack.self, from: Data(response.body.utf8))

        #expect(response.statusCode == 200)
        #expect(response.headers["Content-Type"] == "application/json")
        #expect(pack.routes == [previousRoute])
        #expect(pack.currentRouteId == previousRoute.id)
    }
}

private extension LatestDistrictRouteRouterTest {
    func make(
        districtRepository: DistrictRepositoryMock,
        periodRepository: PeriodRepositoryMock,
        routeRepository: RouteRepositoryMock,
        performanceRepository: PerformanceRepositoryMock,
        pointRepository: PointRepositoryMock,
        passageRepository: PassageRepositoryMock
    ) -> Application {
        withDependencies {
            $0[FestivalControllerKey.self] = FestivalControllerMock()
            $0[DistrictControllerKey.self] = DistrictControllerMock()
            $0[RouteControllerKey.self] = RouteControllerMock()
            $0[LocationControllerKey.self] = LocationControllerMock()
            $0[PeriodControllerKey.self] = PeriodControllerMock()
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[PeriodRepositoryKey.self] = periodRepository
            $0[RouteRepositoryKey.self] = routeRepository
            $0[PerformanceRepositoryKey.self] = performanceRepository
            $0[PointRepositoryKey.self] = pointRepository
            $0[PassageRepositoryKey.self] = passageRepository
            $0[SceneControllerKey.self] = SceneController()
            $0[SceneUsecaseKey.self] = SceneUsecase()
        } operation: {
            Application {
                AuthMiddleware(path: "/")
                FestivalRouter()
                DistrictRouter()
                OtherRouter()
            }
        }
    }
}
