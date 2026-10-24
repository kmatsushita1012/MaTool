import Dependencies
import Foundation
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
    func launchFestival_正常_別祭典の管理者には公開用データのみ返す() async {
        let festival = Festival.mock(id: "festival-target")
        let users: [UserRole] = [
            .headquarter("festival-user"),
            .district("district-user")
        ]

        for user in users {
            let authManager = AuthManagerMock(getAccessTokenHandler: { _ in user })
            let checkpointRepository = CheckpointRepositoryMock(queryHandler: { _ in
                [.mock(id: "private-checkpoint-sentinel", festivalId: festival.id)]
            })
            let hazardRepository = HazardSectionRepositoryMock(queryHandler: { _ in
                [.mock(id: "private-hazard-sentinel", festivalId: festival.id)]
            })
            let festivalRepository = FestivalRepositoryMock(getHandler: { _ in festival })
            let districtRepository = DistrictRepositoryMock(queryHandler: { _ in [] })
            let periodRepository = PeriodRepositoryMock(queryByYearHandler: { _, _ in [] })
            let locationRepository = LocationRepositoryMock()
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

            #expect(response.statusCode == 200)
            #expect(response.body.contains(festival.id))
            #expect(!response.body.contains("private-checkpoint-sentinel"))
            #expect(!response.body.contains("private-hazard-sentinel"))
            #expect(authManager.getAccessTokenCallCount == 1)
            #expect(festivalRepository.getCallCount == 1)
            #expect(districtRepository.queryCallCount == 1)
            #expect(checkpointRepository.queryCallCount == 0)
            #expect(hazardRepository.queryCallCount == 0)
        }
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

struct FestivalPackScopeRouterTest {
    @Test
    func put_異常_チェックポイントが別祭典_書き込み前に拒否() async throws {
        let harness = makeHarness()
        let original = harness.store.snapshot()
        let pack = FestivalPack.mock(
            festival: .mock(id: "festival-1", name: "updated"),
            checkpoints: [.mock(id: "checkpoint-2", festivalId: "festival-2")]
        )

        let response = await harness.handle(try request(pack, pathFestivalId: "festival-1", user: .headquarter("festival-1")))

        #expect(response.statusCode == 400)
        #expect(response.body.contains("祭典と子要素の祭典IDが一致しません。"))
        #expect(harness.store.snapshot() == original)
        #expect(harness.festivalRepository.putCount == 0)
        #expect(harness.checkpointRepository.queryCallCount == 0)
        #expect(harness.checkpointRepository.postCallCount == 0)
        #expect(harness.checkpointRepository.putCallCount == 0)
        #expect(harness.checkpointRepository.deleteCallCount == 0)
        #expect(harness.hazardSectionRepository.queryCallCount == 0)
        #expect(harness.hazardSectionRepository.postCallCount == 0)
        #expect(harness.hazardSectionRepository.putCallCount == 0)
        #expect(harness.hazardSectionRepository.deleteCallCount == 0)
    }

    @Test
    func put_異常_危険区間が別祭典_書き込み前に拒否() async throws {
        let harness = makeHarness()
        let original = harness.store.snapshot()
        let pack = FestivalPack.mock(
            festival: .mock(id: "festival-1", name: "updated"),
            hazardSections: [.mock(id: "hazard-2", festivalId: "festival-2")]
        )

        let response = await harness.handle(try request(pack, pathFestivalId: "festival-1", user: .headquarter("festival-1")))

        #expect(response.statusCode == 400)
        #expect(response.body.contains("祭典と子要素の祭典IDが一致しません。"))
        #expect(harness.store.snapshot() == original)
        #expect(harness.festivalRepository.putCount == 0)
        #expect(harness.checkpointRepository.queryCallCount == 0)
        #expect(harness.hazardSectionRepository.queryCallCount == 0)
        #expect(harness.checkpointRepository.postCallCount + harness.checkpointRepository.putCallCount + harness.checkpointRepository.deleteCallCount == 0)
        #expect(harness.hazardSectionRepository.postCallCount + harness.hazardSectionRepository.putCallCount + harness.hazardSectionRepository.deleteCallCount == 0)
    }

    @Test
    func put_異常_URLと本文の祭典が不一致_書き込み前に拒否() async throws {
        let harness = makeHarness()
        let original = harness.store.snapshot()
        let pack = FestivalPack.mock(festival: .mock(id: "festival-2", name: "updated"))

        let response = await harness.handle(try request(pack, pathFestivalId: "festival-1", user: .headquarter("festival-2")))

        #expect(response.statusCode == 400)
        #expect(response.body.contains("URLの祭典IDと送信データの祭典IDが一致しません。"))
        #expect(harness.store.snapshot() == original)
        #expect(harness.festivalRepository.putCount == 0)
        #expect(harness.checkpointRepository.queryCallCount == 0)
        #expect(harness.hazardSectionRepository.queryCallCount == 0)
        #expect(harness.checkpointRepository.postCallCount + harness.checkpointRepository.putCallCount + harness.checkpointRepository.deleteCallCount == 0)
        #expect(harness.hazardSectionRepository.postCallCount + harness.hazardSectionRepository.putCallCount + harness.hazardSectionRepository.deleteCallCount == 0)
    }

    @Test
    func put_異常_本部権限が別祭典_書き込み前に拒否() async throws {
        let harness = makeHarness()
        let original = harness.store.snapshot()
        let pack = FestivalPack.mock(
            festival: .mock(id: "festival-1", name: "updated"),
            checkpoints: [.mock(id: "checkpoint-1", festivalId: "festival-1", name: "updated")]
        )

        let response = await harness.handle(try request(pack, pathFestivalId: "festival-1", user: .headquarter("festival-2")))

        #expect(response.statusCode == 401)
        #expect(response.body.contains("アクセス権限がありません。"))
        #expect(harness.store.snapshot() == original)
        #expect(harness.festivalRepository.putCount == 0)
        #expect(harness.checkpointRepository.queryCallCount == 0)
        #expect(harness.hazardSectionRepository.queryCallCount == 0)
        #expect(harness.checkpointRepository.postCallCount + harness.checkpointRepository.putCallCount + harness.checkpointRepository.deleteCallCount == 0)
        #expect(harness.hazardSectionRepository.postCallCount + harness.hazardSectionRepository.putCallCount + harness.hazardSectionRepository.deleteCallCount == 0)
    }

    @Test
    func put_正常_同じ祭典の子要素を更新して状態を保存() async throws {
        let harness = makeHarness()
        let pack = FestivalPack.mock(
            festival: .mock(id: "festival-1", name: "festival-updated"),
            checkpoints: [.mock(id: "checkpoint-1", festivalId: "festival-1", name: "checkpoint-updated")],
            hazardSections: [.mock(id: "hazard-1", festivalId: "festival-1", title: "hazard-updated")]
        )

        let response = await harness.handle(try request(pack, pathFestivalId: "festival-1", user: .headquarter("festival-1")))
        let responsePack = try FestivalPack.from(response.body)
        let saved = harness.store.snapshot()

        #expect(response.statusCode == 200)
        #expect(responsePack == pack)
        #expect(saved.festival == pack.festival)
        #expect(saved.checkpoints == pack.checkpoints)
        #expect(saved.hazardSections == pack.hazardSections)
        #expect(harness.festivalRepository.putCount == 1)
        #expect(harness.checkpointRepository.queryCallCount == 1)
        #expect(harness.checkpointRepository.putCallCount == 1)
        #expect(harness.hazardSectionRepository.queryCallCount == 1)
        #expect(harness.hazardSectionRepository.putCallCount == 1)
    }
}
