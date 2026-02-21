import Dependencies
import Testing
@testable import Backend

struct DistrictRouterTest {
    @Test
    func routesDistrictCoreToUpdateDistrictController() async {
        var capturedDistrictId: String?
        let districtController = DistrictControllerMock(
            updateDistrictHandler: { request, _ in
                capturedDistrictId = request.parameters["districtId"]
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
        #expect(capturedDistrictId == "district-9")
    }
}
