import Dependencies
import Shared
import Testing
@testable import Backend

struct RoutePackOwnershipRouterTest {
    @Test
    func post_別routeIdのPointを拒否し書き込みを行わない() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let point = Point.mock(id: "point-1", routeId: "route-2", index: 0, anchor: .start)
        let pack = RoutePack.mock(route: route, points: [point])

        let (response, routeRepository, pointRepository, passageRepository) = try await send(
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

        let (response, routeRepository, pointRepository, passageRepository) = try await send(
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
    func put_別routeIdのPointを拒否し書き込みを行わない() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let point = Point.mock(id: "point-1", routeId: "route-2", index: 0, anchor: .start)
        let pack = RoutePack.mock(route: route, points: [point])

        let (response, routeRepository, pointRepository, passageRepository) = try await send(
            method: .put,
            path: "/routes/route-1",
            pack: pack,
            existingRoute: route
        )

        #expect(response.statusCode == 400)
        #expect(response.body.contains("ルートと子要素のrouteIdが一致しません。"))
        #expect(routeRepository.postCallCount == 0)
        #expect(routeRepository.putCallCount == 0)
        #expect(pointRepository.postCallCount == 0)
        #expect(pointRepository.putCallCount == 0)
        #expect(passageRepository.postCallCount == 0)
        #expect(passageRepository.putCallCount == 0)
    }

    @Test
    func put_別routeIdのPassageを拒否し書き込みを行わない() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let passage = RoutePassage.mock(id: "passage-1", routeId: "route-2", districtId: "district-1")
        let pack = RoutePack.mock(route: route, passages: [passage])

        let (response, routeRepository, pointRepository, passageRepository) = try await send(
            method: .put,
            path: "/routes/route-1",
            pack: pack,
            existingRoute: route
        )

        #expect(response.statusCode == 400)
        #expect(response.body.contains("ルートと子要素のrouteIdが一致しません。"))
        #expect(routeRepository.postCallCount == 0)
        #expect(routeRepository.putCallCount == 0)
        #expect(pointRepository.postCallCount == 0)
        #expect(pointRepository.putCallCount == 0)
        #expect(passageRepository.postCallCount == 0)
        #expect(passageRepository.putCallCount == 0)
    }
}

private extension RoutePackOwnershipRouterTest {
    func send(
        method: Application.Method,
        path: String,
        pack: RoutePack,
        existingRoute: Route? = nil
    ) async throws -> (Application.Response, RouteRepositoryMock, PointRepositoryMock, PassageRepositoryMock) {
        let routeRepository = RouteRepositoryMock(
            getHandler: { _ in existingRoute },
            postHandler: { $0 },
            putHandler: { $0 }
        )
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in district })
        let pointRepository = PointRepositoryMock(
            queryHandler: { _ in [] },
            postHandler: { $0 },
            putHandler: { $0 }
        )
        let passageRepository = PassageRepositoryMock(
            queryHandler: { _ in [] },
            postHandler: { $0 },
            putHandler: { $0 }
        )
        let body = try pack.toString()

        let response = await withDependencies {
            $0[RouteRepositoryKey.self] = routeRepository
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[FestivalRepositoryKey.self] = FestivalRepositoryMock()
            $0[PointRepositoryKey.self] = pointRepository
            $0[PassageRepositoryKey.self] = passageRepository
            $0[DistrictControllerKey.self] = DistrictControllerMock()
            $0[LocationControllerKey.self] = LocationControllerMock()
            $0[PeriodControllerKey.self] = PeriodControllerMock()
            $0[SceneControllerKey.self] = SceneControllerMock()
            $0[RouteUsecaseKey.self] = RouteUsecase()
            $0[RouteControllerKey.self] = RouteController()
        } operation: {
            let app = Application { DistrictRouter(); OtherRouter() }
            var request = Application.Request.make(method: method, path: path, body: body)
            request.user = .district("district-1")
            return await app.handle(request)
        }

        return (response, routeRepository, pointRepository, passageRepository)
    }
}
