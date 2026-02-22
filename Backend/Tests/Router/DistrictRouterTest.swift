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
        let routeController = RouteControllerMock()
        let locationController = LocationControllerMock()
        let sceneController = SceneControllerMock()

        let response = await withDependencies {
            $0[DistrictControllerKey.self] = districtController
            $0[RouteControllerKey.self] = routeController
            $0[LocationControllerKey.self] = locationController
            $0[SceneControllerKey.self] = sceneController
        } operation: {
            let app = Application { DistrictRouter() }
            let request = Application.Request.make(method: .put, path: "/districts/district-9/core")
            return await app.handle(request)
        }

        #expect(response.statusCode == 200)
        #expect(districtController.updateDistrictCallCount == 1)
        #expect(lastCalledDistrictId == "district-9")
    }

    @Test
    func routesRouteQueryToRouteController_正常() async {
        let districtController = DistrictControllerMock()
        let routeController = RouteControllerMock(queryHandler: { _, _ in try .success() })
        let locationController = LocationControllerMock()
        let sceneController = SceneControllerMock()

        let response = await withDependencies {
            $0[DistrictControllerKey.self] = districtController
            $0[RouteControllerKey.self] = routeController
            $0[LocationControllerKey.self] = locationController
            $0[SceneControllerKey.self] = sceneController
        } operation: {
            let app = Application { DistrictRouter() }
            let request = Application.Request.make(method: .get, path: "/districts/district-1/routes")
            return await app.handle(request)
        }

        #expect(response.statusCode == 200)
        #expect(routeController.queryCallCount == 1)
    }

    @Test
    func routesLaunchFestivalToSceneController_正常() async {
        let districtController = DistrictControllerMock()
        let routeController = RouteControllerMock()
        let locationController = LocationControllerMock()
        let sceneController = SceneControllerMock(launchFestivalHandler: { _, _ in try .success() })

        let response = await withDependencies {
            $0[DistrictControllerKey.self] = districtController
            $0[RouteControllerKey.self] = routeController
            $0[LocationControllerKey.self] = locationController
            $0[SceneControllerKey.self] = sceneController
        } operation: {
            let app = Application { DistrictRouter() }
            let request = Application.Request.make(method: .get, path: "/districts/district-1/launch-festival")
            return await app.handle(request)
        }

        #expect(response.statusCode == 200)
        #expect(sceneController.launchFestivalCallCount == 1)
    }
}
