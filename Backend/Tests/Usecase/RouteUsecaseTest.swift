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
