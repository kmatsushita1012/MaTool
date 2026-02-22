import Dependencies
import Testing
@testable import Backend

struct OtherRouterTest {
    @Test
    func routesPeriodGetToPeriodController_正常() async {
        var lastCalledPeriodId: String?
        let routeController = RouteControllerMock()
        let periodController = PeriodControllerMock(
            getHandler: { request, _ in
                lastCalledPeriodId = request.parameters["periodId"]
                return try .success()
            }
        )

        let response = await withDependencies {
            $0[RouteControllerKey.self] = routeController
            $0[PeriodControllerKey.self] = periodController
        } operation: {
            let app = Application { OtherRouter() }
            let request = Application.Request.make(method: .get, path: "/periods/period-1")
            return await app.handle(request)
        }

        #expect(response.statusCode == 200)
        #expect(periodController.getCallCount == 1)
        #expect(lastCalledPeriodId == "period-1")
    }

    @Test
    func routesRouteDeleteToRouteController_正常() async {
        let routeController = RouteControllerMock(deleteHandler: { _, _ in try .success() })
        let periodController = PeriodControllerMock()

        let response = await withDependencies {
            $0[RouteControllerKey.self] = routeController
            $0[PeriodControllerKey.self] = periodController
        } operation: {
            let app = Application { OtherRouter() }
            let request = Application.Request.make(method: .delete, path: "/routes/route-1")
            return await app.handle(request)
        }

        #expect(response.statusCode == 200)
        #expect(routeController.deleteCallCount == 1)
    }

    @Test
    func routesPeriodPutToPeriodController_正常() async {
        let routeController = RouteControllerMock()
        let periodController = PeriodControllerMock(putHandler: { _, _ in try .success() })

        let response = await withDependencies {
            $0[RouteControllerKey.self] = routeController
            $0[PeriodControllerKey.self] = periodController
        } operation: {
            let app = Application { OtherRouter() }
            let request = Application.Request.make(method: .put, path: "/periods/period-1")
            return await app.handle(request)
        }

        #expect(response.statusCode == 200)
        #expect(periodController.putCallCount == 1)
    }
}
