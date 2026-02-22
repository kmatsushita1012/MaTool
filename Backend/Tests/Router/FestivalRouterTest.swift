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
        let app = make(festivalController: festivalController)
        let request = Application.Request.make(method: .get, path: "/festivals/festival-1")
        let response = await app.handle(request)

        #expect(response.statusCode == 200)
        #expect(festivalController.getCallCount == 1)
        #expect(lastCalledFestivalId == "festival-1")
    }

    @Test
    func routesDistrictPostToDistrictController_正常() async {
        let districtController = DistrictControllerMock(postHandler: { _, _ in try .success() })
        let app = make(districtController: districtController)
        let request = Application.Request.make(method: .post, path: "/festivals/festival-1/districts")
        let response = await app.handle(request)

        #expect(response.statusCode == 200)
        #expect(districtController.postCallCount == 1)
    }

    @Test
    func routesLaunchToSceneController_正常() async {
        let sceneController = SceneControllerMock(launchFestivalHandler: { _, _ in try .success() })

        let app = make(sceneController: sceneController)
        let request = Application.Request.make(method: .get, path: "/festivals/festival-1/launch")
        let response = await app.handle(request)

        #expect(response.statusCode == 200)
        #expect(sceneController.launchFestivalCallCount == 1)
    }

    @Test
    func routesFestival_異常_コントローラ例外で500() async {
        let festivalController = FestivalControllerMock(getHandler: { _, _ in throw TestError.intentional })
        let app = make(festivalController: festivalController)
        let request = Application.Request.make(method: .get, path: "/festivals/festival-1")
        let response = await app.handle(request)

        #expect(response.statusCode == 500)
        #expect(festivalController.getCallCount == 1)
    }
}

private extension FestivalRouterTest {
    func make(
        festivalController: FestivalControllerMock = .init(),
        districtController: DistrictControllerMock = .init(),
        locationController: LocationControllerMock = .init(),
        periodController: PeriodControllerMock = .init(),
        sceneController: SceneControllerMock = .init()
    ) -> Application {
        withDependencies {
            $0[FestivalControllerKey.self] = festivalController
            $0[DistrictControllerKey.self] = districtController
            $0[LocationControllerKey.self] = locationController
            $0[PeriodControllerKey.self] = periodController
            $0[SceneControllerKey.self] = sceneController
        } operation: {
            Application { FestivalRouter() }
        }
    }
}
