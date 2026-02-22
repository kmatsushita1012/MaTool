import Dependencies
import Testing
@testable import Backend

struct FestivalRouterTest {
    @Test
    func routesFestivalGetToFestivalController_正常() async {
        var lastCalledFestivalId: String?
        let festivalController = FestivalControllerMock(
            getHandler: { request, _ in
                lastCalledFestivalId = request.parameters["festivalId"]
                return try .success()
            }
        )
        let districtController = DistrictControllerMock()
        let locationController = LocationControllerMock()
        let periodController = PeriodControllerMock()
        let sceneController = SceneControllerMock()

        let response = await withDependencies {
            $0[FestivalControllerKey.self] = festivalController
            $0[DistrictControllerKey.self] = districtController
            $0[LocationControllerKey.self] = locationController
            $0[PeriodControllerKey.self] = periodController
            $0[SceneControllerKey.self] = sceneController
        } operation: {
            let app = Application { FestivalRouter() }
            let request = Application.Request.make(method: .get, path: "/festivals/festival-1")
            return await app.handle(request)
        }

        #expect(response.statusCode == 200)
        #expect(festivalController.getCallCount == 1)
        #expect(lastCalledFestivalId == "festival-1")
    }

    @Test
    func routesDistrictPostToDistrictController_正常() async {
        let festivalController = FestivalControllerMock()
        let districtController = DistrictControllerMock(postHandler: { _, _ in try .success() })
        let locationController = LocationControllerMock()
        let periodController = PeriodControllerMock()
        let sceneController = SceneControllerMock()

        let response = await withDependencies {
            $0[FestivalControllerKey.self] = festivalController
            $0[DistrictControllerKey.self] = districtController
            $0[LocationControllerKey.self] = locationController
            $0[PeriodControllerKey.self] = periodController
            $0[SceneControllerKey.self] = sceneController
        } operation: {
            let app = Application { FestivalRouter() }
            let request = Application.Request.make(method: .post, path: "/festivals/festival-1/districts")
            return await app.handle(request)
        }

        #expect(response.statusCode == 200)
        #expect(districtController.postCallCount == 1)
    }

    @Test
    func routesLaunchToSceneController_正常() async {
        let festivalController = FestivalControllerMock()
        let districtController = DistrictControllerMock()
        let locationController = LocationControllerMock()
        let periodController = PeriodControllerMock()
        let sceneController = SceneControllerMock(launchFestivalHandler: { _, _ in try .success() })

        let response = await withDependencies {
            $0[FestivalControllerKey.self] = festivalController
            $0[DistrictControllerKey.self] = districtController
            $0[LocationControllerKey.self] = locationController
            $0[PeriodControllerKey.self] = periodController
            $0[SceneControllerKey.self] = sceneController
        } operation: {
            let app = Application { FestivalRouter() }
            let request = Application.Request.make(method: .get, path: "/festivals/festival-1/launch")
            return await app.handle(request)
        }

        #expect(response.statusCode == 200)
        #expect(sceneController.launchFestivalCallCount == 1)
    }
}
