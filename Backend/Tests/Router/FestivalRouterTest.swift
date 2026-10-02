import Dependencies
import Shared
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
    func launchFestival_異常_別祭典の本部アカウントには403を返す() async {
        let authManager = AuthManagerMock(getAccessTokenHandler: { _ in .headquarter("festival-user") })
        let festivalRepository = FestivalRepositoryMock()
        let districtRepository = DistrictRepositoryMock()
        let periodRepository = PeriodRepositoryMock()
        let locationRepository = LocationRepositoryMock()
        let checkpointRepository = CheckpointRepositoryMock()
        let hazardRepository = HazardSectionRepositoryMock()
        let performanceRepository = PerformanceRepositoryMock()
        let routeRepository = RouteRepositoryMock()
        let pointRepository = PointRepositoryMock()
        let passageRepository = PassageRepositoryMock()
        let request = Application.Request.make(
            method: .get,
            path: "/festivals/festival-target/launch",
            headers: ["authorization": "Bearer test-token"]
        )

        let response = await withDependencies {
            $0[AuthManagerFactoryKey.self] = { authManager }
            $0[FestivalRepositoryKey.self] = festivalRepository
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[PeriodRepositoryKey.self] = periodRepository
            $0[LocationRepositoryKey.self] = locationRepository
            $0[CheckpointRepositoryKey.self] = checkpointRepository
            $0[HazardSectionRepositoryKey.self] = hazardRepository
            $0[PerformanceRepositoryKey.self] = performanceRepository
            $0[RouteRepositoryKey.self] = routeRepository
            $0[PointRepositoryKey.self] = pointRepository
            $0[PassageRepositoryKey.self] = passageRepository
            $0[SceneUsecaseKey.self] = SceneUsecase()
            $0[FestivalControllerKey.self] = FestivalControllerMock()
            $0[DistrictControllerKey.self] = DistrictControllerMock()
            $0[LocationControllerKey.self] = LocationControllerMock()
            $0[PeriodControllerKey.self] = PeriodControllerMock()
            $0[SceneControllerKey.self] = SceneController()
        } operation: {
            let app = Application {
                AuthMiddleware(path: "/")
                FestivalRouter()
            }
            return await app.handle(request)
        }

        #expect(response.statusCode == 403)
        #expect(response.body.contains("この祭典の管理用データにアクセスする権限がありません"))
        #expect(authManager.getAccessTokenCallCount == 1)
        #expect(festivalRepository.getCallCount == 0)
        #expect(districtRepository.queryCallCount == 0)
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
