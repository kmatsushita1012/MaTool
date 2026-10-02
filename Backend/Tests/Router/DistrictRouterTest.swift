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
        var middlewareCallCount = 0
        let app = Application()
        app.use(path: "/api") { request, next in
            middlewareCallCount += 1
            return try await next(request)
        }
        app.get(path: "/api/items/:itemId") { _, _ in try .success() }

        let request = Application.Request.make(method: .get, path: "/api/items/item-1")
        let response = await app.handle(request)

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
