import Dependencies
import Testing
@testable import Backend

struct OtherRouterTest {
    @Test
    func routesPeriodGetToPeriodController() async {
        var capturedPeriodId: String?
        let routeController = RouteControllerMock()
        let periodController = PeriodControllerMock(
            getHandler: { request, _ in
                capturedPeriodId = request.parameters["periodId"]
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
        #expect(capturedPeriodId == "period-1")
    }
}
