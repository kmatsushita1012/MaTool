import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct RouteUsecaseTest {
    @Test
    func get_visibilityAll_returnsRoutePack() async throws {
        let district = District(id: "district-1", name: "d", festivalId: "festival-1", visibility: .all)
        let route = Route(id: "route-1", districtId: district.id, periodId: "period-1", visibility: .all)
        let point = Point(routeId: route.id, coordinate: .init(latitude: 35, longitude: 139))
        let passage = RoutePassage(routeId: route.id, districtId: district.id)

        let subject = make(
            routeRepository: .init(getHandler: { _ in route }),
            districtRepository: .init(getHandler: { _ in district }),
            pointRepository: .init(queryHandler: { _ in [point] }),
            passageRepository: .init(queryHandler: { _ in [passage] })
        )

        let result = try await subject.get(id: route.id, user: .guest)

        #expect(result.route == route)
        #expect(result.points == [point])
        #expect(result.passages == [passage])
    }

    @Test
    func get_notFound_throws() async {
        let subject = make(
            routeRepository: .init(getHandler: { _ in nil }),
            districtRepository: .init(),
            pointRepository: .init(),
            passageRepository: .init()
        )

        await #expect(throws: Error.notFound("指定されたルートが見つかりません")) {
            _ = try await subject.get(id: "route-missing", user: .guest)
        }
    }

    @Test
    func get_adminRoute_guestForbidden() async {
        let district = District(id: "district-1", name: "d", festivalId: "festival-1", visibility: .all)
        let route = Route(id: "route-1", districtId: district.id, periodId: "period-1", visibility: .admin)

        let subject = make(
            routeRepository: .init(getHandler: { _ in route }),
            districtRepository: .init(getHandler: { _ in district }),
            pointRepository: .init(),
            passageRepository: .init()
        )

        await #expect(throws: Error.forbidden("アクセス権限がありせん。このルートは非公開です。")) {
            _ = try await subject.get(id: route.id, user: .guest)
        }
    }

    @Test
    func query_all_forwardsToRepository() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let routes = [Route.mock(id: "route-1", districtId: district.id)]
        let repository = RouteRepositoryMock(queryHandler: { _ in routes })
        let subject = make(
            routeRepository: repository,
            districtRepository: .init(getHandler: { _ in district }),
            pointRepository: .init(),
            passageRepository: .init()
        )

        let result = try await subject.query(by: district.id, type: .all, now: .init(year: 2026, month: 1, day: 1), user: .guest)

        #expect(result == routes)
        #expect(repository.queryCallCount == 1)
    }

    @Test
    func query_latest_prefersNextYear() async throws {
        let district = District(id: "district-1", name: "d", festivalId: "festival-1", visibility: .all)
        let now = SimpleDate(year: 2026, month: 2, day: 1)
        let nextYearRoute = Route(id: "route-next", districtId: district.id, periodId: "period-next", visibility: .all)

        let subject = make(
            routeRepository: .init(
                queryHandler: { _ in [] },
                queryByYearHandler: { _, year in
                    if year == 2027 { return [nextYearRoute] }
                    return []
                }
            ),
            districtRepository: .init(getHandler: { _ in district }),
            pointRepository: .init(),
            passageRepository: .init()
        )

        let result = try await subject.query(by: district.id, type: .latest, now: now, user: .guest)

        #expect(result == [nextYearRoute])
    }

    @Test
    func query_latest_fallsBackToLastYear() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let lastYearRoute = Route.mock(id: "route-last", districtId: district.id)

        let subject = make(
            routeRepository: .init(
                queryByYearHandler: { _, year in
                    if year == 2025 { return [lastYearRoute] }
                    return []
                }
            ),
            districtRepository: .init(getHandler: { _ in district }),
            pointRepository: .init(),
            passageRepository: .init()
        )

        let result = try await subject.query(
            by: district.id,
            type: .latest,
            now: .init(year: 2026, month: 2, day: 1),
            user: .guest
        )

        #expect(result == [lastYearRoute])
    }

    @Test
    func post_unauthorized_throws() async {
        let pack = RoutePack.mock(route: .mock(id: "route-1", districtId: "district-1"), points: [], passages: [])
        let subject = make(
            routeRepository: .init(),
            districtRepository: .init(),
            pointRepository: .init(),
            passageRepository: .init()
        )

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            _ = try await subject.post(districtId: "district-1", pack: pack, user: .guest)
        }
    }

    @Test
    func post_authorized_createsRoutePack() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let points = [
            Point.mock(id: "p-1", routeId: route.id, index: 0, time: .init(hour: 9, minute: 0), anchor: .start),
            Point.mock(id: "p-2", routeId: route.id, index: 1, time: .init(hour: 10, minute: 0), anchor: .end)
        ]
        let passages = [RoutePassage.mock(id: "pa-1", routeId: route.id, districtId: route.districtId, order: 0)]
        let pack = RoutePack.mock(route: route, points: points, passages: passages)

        let subject = make(
            routeRepository: .init(postHandler: { $0 }),
            districtRepository: .init(),
            pointRepository: .init(queryHandler: { _ in [] }, postHandler: { $0 }),
            passageRepository: .init(queryHandler: { _ in [] }, postHandler: { $0 })
        )

        let result = try await subject.post(districtId: route.districtId, pack: pack, user: .district(route.districtId))

        #expect(result.route == route)
        #expect(result.points.count == 2)
        #expect(result.passages.count == 1)
    }

    @Test
    func put_notFound_throws() async {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let pack = RoutePack.mock(route: route, points: [], passages: [])
        let subject = make(
            routeRepository: .init(getHandler: { _ in nil }),
            districtRepository: .init(),
            pointRepository: .init(),
            passageRepository: .init()
        )

        await #expect(throws: Error.notFound("指定されたルートが見つかりません")) {
            _ = try await subject.put(id: route.id, pack: pack, user: .district(route.districtId))
        }
    }

    @Test
    func put_authorized_updatesRoutePack() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let points = [
            Point.mock(id: "p-1", routeId: route.id, index: 0, time: .init(hour: 9, minute: 0), anchor: .start),
            Point.mock(id: "p-2", routeId: route.id, index: 1, time: .init(hour: 10, minute: 0), anchor: .end)
        ]
        let pack = RoutePack.mock(route: route, points: points, passages: [])
        let subject = make(
            routeRepository: .init(getHandler: { _ in route }, postHandler: { $0 }),
            districtRepository: .init(),
            pointRepository: .init(queryHandler: { _ in [] }, postHandler: { $0 }),
            passageRepository: .init(queryHandler: { _ in [] })
        )

        let result = try await subject.put(id: route.id, pack: pack, user: .district(route.districtId))

        #expect(result.route == route)
        #expect(result.points.count == 2)
    }

    @Test
    func delete_userMismatch_throwsUnauthorized() async {
        let route = Route(id: "route-1", districtId: "district-1", periodId: "period-1")

        let subject = make(
            routeRepository: .init(getHandler: { _ in route }),
            districtRepository: .init(),
            pointRepository: .init(),
            passageRepository: .init()
        )

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            try await subject.delete(id: route.id, user: .district("other"))
        }
    }

    @Test
    func delete_authorized_deletesRoutePointsAndPassages() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let routeRepository = RouteRepositoryMock(
            getHandler: { _ in route },
            deleteHandler: { _ in }
        )
        let pointRepository = PointRepositoryMock(deleteByRouteHandler: { _ in })
        let passageRepository = PassageRepositoryMock(deleteByRouteHandler: { _ in })

        let subject = make(
            routeRepository: routeRepository,
            districtRepository: .init(),
            pointRepository: pointRepository,
            passageRepository: passageRepository
        )

        try await subject.delete(id: route.id, user: .district(route.districtId))

        #expect(routeRepository.deleteCallCount == 1)
        #expect(pointRepository.deleteByRouteCallCount == 1)
        #expect(passageRepository.deleteByRouteCallCount == 1)
    }
}

private extension RouteUsecaseTest {
    func make(
        routeRepository: RouteRepositoryMock,
        districtRepository: DistrictRepositoryMock,
        pointRepository: PointRepositoryMock,
        passageRepository: PassageRepositoryMock
    ) -> RouteUsecase {
        withDependencies {
            $0[RouteRepositoryKey.self] = routeRepository
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[PointRepositoryKey.self] = pointRepository
            $0[PassageRepositoryKey.self] = passageRepository
        } operation: {
            RouteUsecase()
        }
    }
}
