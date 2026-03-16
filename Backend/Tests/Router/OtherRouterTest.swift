import Dependencies
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
    func routesRouteSnapshotGetToSnapshotController_正常() async {
        var calledRouteId: String?
        let app = make(routeSnapshotController: .init(
            getHandler: { request, _ in
                calledRouteId = request.parameters["routeId"]
                return .binary(base64: "ZmFrZQ==", contentType: "image/png")
            }
        ))
        let request = Application.Request.make(method: .get, path: "/routes/route-1/snapshot")
        let response = await app.handle(request)

        #expect(response.statusCode == 200)
        #expect(response.headers["Content-Type"] == "image/png")
        #expect(response.isBase64Encoded == true)
        #expect(calledRouteId == "route-1")
    }

    @Test
    func routesRouteSnapshotPostToSnapshotController_正常() async {
        let app = make(routeSnapshotController: .init(
            postHandler: { _, _ in
                .binary(base64: "cG9zdA==", contentType: "image/png")
            }
        ))
        let request = Application.Request.make(method: .post, path: "/routes/snapshot")
        let response = await app.handle(request)

        #expect(response.statusCode == 200)
        #expect(response.headers["Content-Type"] == "image/png")
        #expect(response.isBase64Encoded == true)
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
        routeSnapshotController: RouteSnapshotControllerMock = .init(),
        periodController: PeriodControllerMock = .init()
    ) -> Application {
        withDependencies {
            $0[RouteControllerKey.self] = routeController
            $0[RouteSnapshotControllerKey.self] = routeSnapshotController
            $0[PeriodControllerKey.self] = periodController
        } operation: {
            Application { OtherRouter() }
        }
    }
}
