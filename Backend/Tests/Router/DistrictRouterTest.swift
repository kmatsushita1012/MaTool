import Dependencies
import Testing
@testable import Backend

struct DistrictRouterTest {
    @Test
    func routesDistrictCoreToUpdateDistrictController_正常() async {
        var lastCalledDistrictId: String?
        let districtController = DistrictControllerMock(
            updateDistrictHandler: { request, _ in
                lastCalledDistrictId = request.parameters["districtId"]
                return try .success()
            }
        )
        let app = make(districtController: districtController)
        let request = Application.Request.make(method: .put, path: "/districts/district-9/core")
        let response = await app.handle(request)

        #expect(response.statusCode == 200)
        #expect(districtController.updateDistrictCallCount == 1)
        #expect(lastCalledDistrictId == "district-9")
    }

    @Test
    func routesRouteQueryToRouteController_正常() async {
        let routeController = RouteControllerMock(queryHandler: { _, _ in try .success() })
        let app = make(routeController: routeController)
        let request = Application.Request.make(method: .get, path: "/districts/district-1/routes")
        let response = await app.handle(request)

        #expect(response.statusCode == 200)
        #expect(routeController.queryCallCount == 1)
    }

    @Test
    func routesLaunchFestivalToSceneController_正常() async {
        let sceneController = SceneControllerMock(launchFestivalHandler: { _, _ in try .success() })

        let app = make(sceneController: sceneController)
        let request = Application.Request.make(method: .get, path: "/districts/district-1/launch-festival")
        let response = await app.handle(request)

        #expect(response.statusCode == 200)
        #expect(sceneController.launchFestivalCallCount == 1)
    }

    @Test
    func routesDistrict_異常_コントローラ例外で500() async {
        let districtController = DistrictControllerMock(getHandler: { _, _ in throw TestError.intentional })
        let app = make(districtController: districtController)
        let request = Application.Request.make(method: .get, path: "/districts/district-1")
        let response = await app.handle(request)

        #expect(response.statusCode == 500)
        #expect(districtController.getCallCount == 1)
    }
}

private extension DistrictRouterTest {
    func make(
        districtController: DistrictControllerMock = .init(),
        routeController: RouteControllerMock = .init(),
        locationController: LocationControllerMock = .init(),
        sceneController: SceneControllerMock = .init()
    ) -> Application {
        withDependencies {
            $0[DistrictControllerKey.self] = districtController
            $0[RouteControllerKey.self] = routeController
            $0[LocationControllerKey.self] = locationController
            $0[SceneControllerKey.self] = sceneController
        } operation: {
            Application { DistrictRouter() }
        }
    }
}
