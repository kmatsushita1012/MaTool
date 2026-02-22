import Dependencies
import Testing
@testable import Backend

struct DistrictRouterTest {
    @Test
    func routesDistrictCoreToUpdateDistrictController_正常() async {
        var lastCalledDistrictId: String?
        let app = make(districtController: .init(
            updateDistrictHandler: { request, _ in
                lastCalledDistrictId = request.parameters["districtId"]
                return try .success()
            }
        ))
        let request = Application.Request.make(method: .put, path: "/districts/district-9/core")
        let response = await app.handle(request)

        #expect(response.statusCode == 200)
        #expect(lastCalledDistrictId == "district-9")
    }

    @Test
    func routesRouteQueryToRouteController_正常() async {
        let app = make(routeController: .init(queryHandler: { _, _ in try .success() }))
        let request = Application.Request.make(method: .get, path: "/districts/district-1/routes")
        let response = await app.handle(request)

        #expect(response.statusCode == 200)
    }

    @Test
    func routesLaunchFestivalToSceneController_正常() async {
        let app = make(sceneController: .init(launchFestivalHandler: { _, _ in try .success() }))
        let request = Application.Request.make(method: .get, path: "/districts/district-1/launch-festival")
        let response = await app.handle(request)

        #expect(response.statusCode == 200)
    }

    @Test
    func routesDistrict_異常_コントローラ例外で500() async {
        let app = make(districtController: .init(getHandler: { _, _ in throw TestError.intentional }))
        let request = Application.Request.make(method: .get, path: "/districts/district-1")
        let response = await app.handle(request)

        #expect(response.statusCode == 500)
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
