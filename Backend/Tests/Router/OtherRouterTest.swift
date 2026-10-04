import Dependencies
import Shared
import Testing
@testable import Backend

struct OtherRouterTest {
    @Test
    func routesPeriodGetToPeriodController_正常() async {
        var lastCalledPeriodId: String?
        let app = make(periodController: .init(
            getHandler: { request, _ in
                lastCalledPeriodId = request.parameters["periodId"]
                return try .success()
            }
        ))
        let request = Application.Request.make(method: .get, path: "/periods/period-1")
        let response = await app.handle(request)

        #expect(response.statusCode == 200)
        #expect(lastCalledPeriodId == "period-1")
    }

    @Test
    func routesRouteDeleteToRouteController_正常() async {
        let app = make(routeController: .init(deleteHandler: { _, _ in try .success() }))
        let request = Application.Request.make(method: .delete, path: "/routes/route-1")
        let response = await app.handle(request)

        #expect(response.statusCode == 200)
    }

    @Test
    func routesRoutePut_異常_URLと本文のRouteID不一致は400でRepositoryを呼ばない() async throws {
        let routeRepository = RouteRepositoryMock()
        let pointRepository = PointRepositoryMock()
        let passageRepository = PassageRepositoryMock()
        let pack = RoutePack.mock(route: .mock(id: "route-body", districtId: "district-1"))
        let request = Application.Request.make(
            method: .put,
            path: "/routes/route-url",
            body: try pack.toString()
        )

        let response = await withDependencies {
            $0[RouteUsecaseKey.self] = RouteUsecase()
            $0[RouteControllerKey.self] = RouteController()
            $0[PeriodControllerKey.self] = PeriodControllerMock()
            $0[RouteRepositoryKey.self] = routeRepository
            $0[PointRepositoryKey.self] = pointRepository
            $0[PassageRepositoryKey.self] = passageRepository
            $0[DistrictRepositoryKey.self] = DistrictRepositoryMock()
            $0[PeriodRepositoryKey.self] = PeriodRepositoryMock()
            $0[FestivalRepositoryKey.self] = FestivalRepositoryMock()
        } operation: {
            let app = Application { OtherRouter() }
            return await app.handle(request)
        }

        #expect(response.statusCode == 400)
        #expect(routeRepository.getCallCount == 0)
        #expect(routeRepository.queryCallCount == 0)
        #expect(routeRepository.queryByYearCallCount == 0)
        #expect(routeRepository.postCallCount == 0)
        #expect(routeRepository.putCallCount == 0)
        #expect(routeRepository.deleteCallCount == 0)
        #expect(routeRepository.deleteRouteCallCount == 0)
        #expect(pointRepository.getCallCount == 0)
        #expect(pointRepository.queryCallCount == 0)
        #expect(pointRepository.postCallCount == 0)
        #expect(pointRepository.putCallCount == 0)
        #expect(pointRepository.deleteItemCallCount == 0)
        #expect(pointRepository.deleteByRouteCallCount == 0)
        #expect(passageRepository.getCallCount == 0)
        #expect(passageRepository.queryCallCount == 0)
        #expect(passageRepository.postCallCount == 0)
        #expect(passageRepository.putCallCount == 0)
        #expect(passageRepository.deleteItemCallCount == 0)
        #expect(passageRepository.deleteByRouteCallCount == 0)
    }

    @Test
    func routesPeriodPutToPeriodController_正常() async {
        let app = make(periodController: .init(putHandler: { _, _ in try .success() }))
        let request = Application.Request.make(method: .put, path: "/periods/period-1")
        let response = await app.handle(request)

        #expect(response.statusCode == 200)
    }

    @Test
    func routesOther_異常_未定義ルートは404() async {
        let app = make()
        let request = Application.Request.make(method: .get, path: "/unknown")
        let response = await app.handle(request)

        #expect(response.statusCode == 404)
    }
}

private extension OtherRouterTest {
    func make(
        routeController: RouteControllerMock = .init(),
        periodController: PeriodControllerMock = .init()
    ) -> Application {
        withDependencies {
            $0[RouteControllerKey.self] = routeController
            $0[PeriodControllerKey.self] = periodController
        } operation: {
            Application { OtherRouter() }
        }
    }
}
