import Dependencies
import Foundation
import Shared
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
    func routesDistrictCore_余分なパス要素があれば404しコントローラを呼ばない() async {
        let districtController = DistrictControllerMock(
            updateDistrictHandler: { _, _ in try .success() }
        )
        let app = make(districtController: districtController)
        let request = Application.Request.make(method: .put, path: "/districts/district-1/core/unexpected")
        let response = await app.handle(request)

        #expect(response.statusCode == 404)
        #expect(response.body == "Not Found")
        #expect(districtController.updateDistrictCallCount == 0)
    }

    @Test
    func middlewarePathは配下のルートに適用される_正常() async {
        let middlewareCallCounter = MiddlewareCallCounter()
        let app = Application()
        app.use(path: "/api") { request, next in
            await middlewareCallCounter.increment()
            return try await next(request)
        }
        app.get(path: "/api/items/:itemId") { _, _ in try .success() }

        let request = Application.Request.make(method: .get, path: "/api/items/item-1")
        let response = await app.handle(request)
        let middlewareCallCount = await middlewareCallCounter.value

        #expect(response.statusCode == 200)
        #expect(middlewareCallCount == 1)
    }

    @Test
    func routesDistrictReissueToDistrictController_正常() async {
        var lastCalledDistrictId: String?
        let app = make(districtController: .init(
            postReissueHandler: { request, _ in
                lastCalledDistrictId = request.parameters["districtId"]
                return try .success()
            }
        ))
        let request = Application.Request.make(method: .post, path: "/districts/district-9/reissue")
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

private actor MiddlewareCallCounter {
    private(set) var value = 0

    func increment() {
        value += 1
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

@Suite(.serialized)
struct DistrictPackScopeHTTPTest {
    @Test
    func put_異常_別地区の演舞を含むパックは400で永続データを変更しない() async throws {
        let ownerDistrictID = "district-owner"
        let foreignDistrictID = "district-other"
        let originalDistrict = District.mock(id: ownerDistrictID, festivalId: "festival-1")
        let originalPerformance = Performance.mock(id: "performance-owner", districtId: ownerDistrictID)
        let foreignPerformance = Performance.mock(id: "performance-other", districtId: foreignDistrictID)
        var persistedDistrict = originalDistrict
        var persistedPerformances = [
            originalPerformance.id: originalPerformance,
            foreignPerformance.id: foreignPerformance,
        ]

        let districtRepository = DistrictRepositoryMock(
            getHandler: { id in id == ownerDistrictID ? persistedDistrict : nil },
            putHandler: { _, item in
                persistedDistrict = item
                return item
            }
        )
        let performanceRepository = PerformanceRepositoryMock(
            queryHandler: { districtID in
                persistedPerformances.values.filter { $0.districtId == districtID }
            },
            postHandler: { item in
                persistedPerformances[item.id] = item
                return item
            },
            putHandler: { item in
                persistedPerformances[item.id] = item
                return item
            },
            deleteHandler: { item in
                persistedPerformances[item.id] = nil
            }
        )
        let incoming = DistrictPack(
            district: .mock(id: ownerDistrictID, festivalId: "festival-1", name: "changed"),
            performances: [foreignPerformance]
        )
        var request = Application.Request.make(
            method: .put,
            path: "/districts/\(ownerDistrictID)",
            body: try incoming.toString()
        )
        request.user = .district(ownerDistrictID)

        let response = await handle(
            request,
            districtRepository: districtRepository,
            performanceRepository: performanceRepository
        )
        let error = try JSONDecoder().decode(ErrorResponse.self, from: Data(response.body.utf8))

        #expect(response.statusCode == 400)
        #expect(error.localizedDescription == "余興データに別の町の余興が含まれています。")
        #expect(districtRepository.getCallCount == 0)
        #expect(districtRepository.putCallCount == 0)
        #expect(performanceRepository.queryCallCount == 0)
        #expect(performanceRepository.postCallCount == 0)
        #expect(performanceRepository.putCallCount == 0)
        #expect(performanceRepository.deleteCallCount == 0)
        #expect(persistedDistrict == originalDistrict)
        #expect(persistedPerformances[originalPerformance.id] == originalPerformance)
        #expect(persistedPerformances[foreignPerformance.id] == foreignPerformance)
    }

    @Test
    func put_正常_同地区の演舞は更新できる() async throws {
        let districtID = "district-owner"
        let originalDistrict = District.mock(id: districtID, festivalId: "festival-1")
        let originalPerformance = Performance.mock(id: "performance-1", districtId: districtID)
        let updatedPerformance = Performance.mock(
            id: originalPerformance.id,
            districtId: districtID,
            name: "updated"
        )
        var persistedDistrict = originalDistrict
        var persistedPerformances = [originalPerformance.id: originalPerformance]

        let districtRepository = DistrictRepositoryMock(
            getHandler: { id in id == districtID ? persistedDistrict : nil },
            putHandler: { _, item in
                persistedDistrict = item
                return item
            }
        )
        let performanceRepository = PerformanceRepositoryMock(
            queryHandler: { requestedDistrictID in
                persistedPerformances.values.filter { $0.districtId == requestedDistrictID }
            },
            putHandler: { item in
                persistedPerformances[item.id] = item
                return item
            }
        )
        let incoming = DistrictPack(
            district: .mock(id: districtID, festivalId: "festival-1", name: "updated district"),
            performances: [updatedPerformance]
        )
        var request = Application.Request.make(
            method: .put,
            path: "/districts/\(districtID)",
            body: try incoming.toString()
        )
        request.user = .district(districtID)

        let response = await handle(
            request,
            districtRepository: districtRepository,
            performanceRepository: performanceRepository
        )
        let pack = try DistrictPack.from(response.body)

        #expect(response.statusCode == 200)
        #expect(pack.district.name == "updated district")
        #expect(pack.performances == [updatedPerformance])
        #expect(persistedDistrict.name == "updated district")
        #expect(persistedPerformances[originalPerformance.id] == updatedPerformance)
        #expect(districtRepository.putCallCount == 1)
        #expect(performanceRepository.queryCallCount == 1)
        #expect(performanceRepository.putCallCount == 1)
    }
}

private extension DistrictPackScopeHTTPTest {
    func handle(
        _ request: Application.Request,
        districtRepository: DistrictRepositoryMock,
        performanceRepository: PerformanceRepositoryMock
    ) async -> Application.Response {
        await withDependencies {
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[PerformanceRepositoryKey.self] = performanceRepository
            $0[RouteRepositoryKey.self] = RouteRepositoryMock()
            $0[PeriodRepositoryKey.self] = PeriodRepositoryMock()
            $0[FestivalRepositoryKey.self] = FestivalRepositoryMock()
            $0[DistrictUsecaseKey.self] = DistrictUsecase()
            $0[DistrictControllerKey.self] = DistrictController()
            $0[RouteControllerKey.self] = RouteControllerMock()
            $0[LocationControllerKey.self] = LocationControllerMock()
            $0[SceneControllerKey.self] = SceneControllerMock()
        } operation: {
            await Application { DistrictRouter() }.handle(request)
        }
    }
}

struct DistrictRoutePackOwnershipTest {
    @Test
    func post_別routeIdのPointを拒否し書き込みを行わない() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let point = Point.mock(id: "point-1", routeId: "route-2", index: 0, anchor: .start)
        let pack = RoutePack.mock(route: route, points: [point])

        let (response, routeRepository, pointRepository, passageRepository) = try await RoutePackHTTPHarness.send(
            method: .post,
            path: "/districts/district-1/routes",
            pack: pack
        )

        #expect(response.statusCode == 400)
        #expect(response.body.contains("ルートと子要素のrouteIdが一致しません。"))
        #expect(routeRepository.postCallCount == 0)
        #expect(pointRepository.postCallCount == 0)
        #expect(pointRepository.putCallCount == 0)
        #expect(passageRepository.postCallCount == 0)
        #expect(passageRepository.putCallCount == 0)
    }

    @Test
    func post_別routeIdのPassageを拒否し書き込みを行わない() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let passage = RoutePassage.mock(id: "passage-1", routeId: "route-2", districtId: "district-1")
        let pack = RoutePack.mock(route: route, passages: [passage])

        let (response, routeRepository, pointRepository, passageRepository) = try await RoutePackHTTPHarness.send(
            method: .post,
            path: "/districts/district-1/routes",
            pack: pack
        )

        #expect(response.statusCode == 400)
        #expect(response.body.contains("ルートと子要素のrouteIdが一致しません。"))
        #expect(routeRepository.postCallCount == 0)
        #expect(pointRepository.postCallCount == 0)
        #expect(pointRepository.putCallCount == 0)
        #expect(passageRepository.postCallCount == 0)
        #expect(passageRepository.putCallCount == 0)
    }


}
