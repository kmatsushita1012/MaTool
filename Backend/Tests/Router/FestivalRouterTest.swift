import Dependencies
import Testing
@testable import Backend

struct FestivalRouterTest {
    @Test
    func routesFestivalGetToFestivalController() async {
        var capturedFestivalId: String?
        let festivalController = FestivalControllerMock(
            getHandler: { request, _ in
                capturedFestivalId = request.parameters["festivalId"]
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
        #expect(capturedFestivalId == "festival-1")
    }
}
