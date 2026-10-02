import Dependencies
import Shared
import Testing
@testable import Backend

struct RoutePackValidationTest {
    @Test
    func put_異常_PointID重複は400で拒否して子要素を読まない() async {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let duplicatePoint = Point.mock(id: "point-duplicate", routeId: route.id)
        let routeRepository = RouteRepositoryMock(getHandler: { _ in route })
        let pointRepository = PointRepositoryMock(queryHandler: { _ in [] })
        let passageRepository = PassageRepositoryMock(queryHandler: { _ in [] })
        let subject = make(
            routeRepository: routeRepository,
            districtRepository: .init(getHandler: { _ in .mock(id: route.districtId, festivalId: "festival-1") }),
            pointRepository: pointRepository,
            passageRepository: passageRepository
        )

        await #expect(throws: Error.badRequest("RoutePackの子要素IDが重複しています。")) {
            _ = try await subject.put(
                id: route.id,
                pack: .mock(route: route, points: [duplicatePoint, duplicatePoint]),
                user: .district(route.districtId)
            )
        }

        #expect(pointRepository.queryCallCount == 0)
        #expect(passageRepository.queryCallCount == 0)
        #expect(routeRepository.putPackCallCount == 0)
    }

    @Test
    func post_異常_PassageID重複は400で拒否して子要素を読まない() async {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let points = [
            Point.mock(id: "point-start", routeId: route.id, time: .init(hour: 9, minute: 0), anchor: .start),
            Point.mock(id: "point-end", routeId: route.id, time: .init(hour: 10, minute: 0), anchor: .end)
        ]
        let duplicatePassage = RoutePassage.mock(id: "passage-duplicate", routeId: route.id)
        let routeRepository = RouteRepositoryMock()
        let pointRepository = PointRepositoryMock(queryHandler: { _ in [] })
        let passageRepository = PassageRepositoryMock(queryHandler: { _ in [] })
        let subject = make(
            routeRepository: routeRepository,
            districtRepository: .init(getHandler: { _ in .mock(id: route.districtId, festivalId: "festival-1") }),
            pointRepository: pointRepository,
            passageRepository: passageRepository
        )

        await #expect(throws: Error.badRequest("RoutePackの子要素IDが重複しています。")) {
            _ = try await subject.post(
                districtId: route.districtId,
                pack: .mock(route: route, points: points, passages: [duplicatePassage, duplicatePassage]),
                user: .district(route.districtId)
            )
        }

        #expect(pointRepository.queryCallCount == 0)
        #expect(passageRepository.queryCallCount == 0)
        #expect(routeRepository.putPackCallCount == 0)
    }
}

private extension RoutePackValidationTest {
    func make(
        routeRepository: RouteRepositoryMock = .init(),
        periodRepository: PeriodRepositoryMock = .init(),
        districtRepository: DistrictRepositoryMock = .init(),
        festivalRepository: FestivalRepositoryMock = .init(),
        pointRepository: PointRepositoryMock = .init(),
        passageRepository: PassageRepositoryMock = .init()
    ) -> RouteUsecase {
        withDependencies {
            $0[RouteRepositoryKey.self] = routeRepository
            $0[PeriodRepositoryKey.self] = periodRepository
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[FestivalRepositoryKey.self] = festivalRepository
            $0[PointRepositoryKey.self] = pointRepository
            $0[PassageRepositoryKey.self] = passageRepository
        } operation: {
            RouteUsecase()
        }
    }
}
