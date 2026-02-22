import Dependencies
import Testing
@testable import Backend

struct FestivalRouterTest {
    @Test
    func routesFestivalGetToFestivalController_正常() async {
        var lastCalledFestivalId: String?
        let app = make(festivalController: .init(
            getHandler: { request, _ in
                lastCalledFestivalId = request.parameters["festivalId"]
                return try .success()
            }
        ))
        let request = Application.Request.make(method: .get, path: "/festivals/festival-1")
        let response = await app.handle(request)

        #expect(response.statusCode == 200)
        #expect(lastCalledFestivalId == "festival-1")
    }

    @Test
    func routesDistrictPostToDistrictController_正常() async {
        let app = make(districtController: .init(postHandler: { _, _ in try .success() }))
        let request = Application.Request.make(method: .post, path: "/festivals/festival-1/districts")
        let response = await app.handle(request)

        #expect(response.statusCode == 200)
    }

    @Test
    func routesLaunchToSceneController_正常() async {
        let app = make(sceneController: .init(launchFestivalHandler: { _, _ in try .success() }))
        let request = Application.Request.make(method: .get, path: "/festivals/festival-1/launch")
        let response = await app.handle(request)

        #expect(response.statusCode == 200)
    }

    @Test
    func routesFestival_異常_コントローラ例外で500() async {
        let app = make(festivalController: .init(getHandler: { _, _ in throw TestError.intentional }))
        let request = Application.Request.make(method: .get, path: "/festivals/festival-1")
        let response = await app.handle(request)

        #expect(response.statusCode == 500)
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
