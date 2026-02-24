import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct RouteUsecaseTest {
    @Test
    func get_正常() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let route = Route.mock(id: "route-1", districtId: district.id, periodId: "period-1")
        let point = Point.mock(routeId: route.id, coordinate: .init(latitude: 35, longitude: 139))
        let passage = RoutePassage.mock(routeId: route.id, districtId: district.id)
        var lastCalledRouteId: String?
        let routeRepository = RouteRepositoryMock(getHandler: { id in
            lastCalledRouteId = id
            return route
        })
        let pointRepository = PointRepositoryMock(queryHandler: { _ in [point] })
        let passageRepository = PassageRepositoryMock(queryHandler: { _ in [passage] })

        let subject = make(
            routeRepository: routeRepository,
            districtRepository: .init(getHandler: { _ in district }),
            pointRepository: pointRepository,
            passageRepository: passageRepository
        )

        let result = try await subject.get(id: route.id, user: .guest)

        #expect(result.route == route)
        #expect(result.points == [point])
        #expect(result.passages == [passage])
        #expect(lastCalledRouteId == route.id)
        #expect(routeRepository.getCallCount == 1)
        #expect(pointRepository.queryCallCount == 1)
        #expect(passageRepository.queryCallCount == 1)
    }

    @Test
    func get_異常_ルート未登録() async {
        let subject = make(
            routeRepository: .init(getHandler: { _ in nil })
        )

        await #expect(throws: Error.notFound("指定されたルートが見つかりません")) {
            _ = try await subject.get(id: "route-missing", user: .guest)
        }
    }

    @Test
    func get_異常_非公開ルートをゲスト参照() async {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let route = Route.mock(id: "route-1", districtId: district.id, periodId: "period-1", visibility: .admin)

        let subject = make(
            routeRepository: .init(getHandler: { _ in route }),
            districtRepository: .init(getHandler: { _ in district })
        )

        await #expect(throws: Error.forbidden("アクセス権限がありせん。このルートは非公開です。")) {
            _ = try await subject.get(id: route.id, user: .guest)
        }
    }

    @Test
    func query_正常_全件取得() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let routes = [Route.mock(id: "route-1", districtId: district.id)]
        let repository = RouteRepositoryMock(queryHandler: { _ in routes })
        let subject = make(
            routeRepository: repository,
            districtRepository: .init(getHandler: { _ in district })
        )

        let result = try await subject.query(by: district.id, type: .all, now: .init(year: 2026, month: 1, day: 1), user: .guest)

        #expect(result == routes)
        #expect(repository.queryCallCount == 1)
    }

    @Test
    func query_正常_latest_翌年Periodありで翌年Routeを採用() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let now = SimpleDate(year: 2026, month: 2, day: 1)
        let nextYearRoute = Route.mock(id: "route-next", districtId: district.id, periodId: "period-next")
        var queriedYears: [Int] = []

        let repository = RouteRepositoryMock(
            queryHandler: { _ in [] },
            queryByYearHandler: { _, year in
                queriedYears.append(year)
                if year == 2027 { return [nextYearRoute] }
                return []
            }
        )
        let periodRepository = PeriodRepositoryMock(queryByYearHandler: { _, year in
            if year == 2027 { return [Period.mock(id: "period-2027", festivalId: district.festivalId, date: .init(year: 2027, month: 1, day: 1))] }
            if year == 2026 { return [Period.mock(id: "period-2026", festivalId: district.festivalId, date: .init(year: 2026, month: 1, day: 1))] }
            return []
        })
        let subject = make(
            routeRepository: repository,
            periodRepository: periodRepository,
            districtRepository: .init(getHandler: { _ in district })
        )

        let result = try await subject.query(by: district.id, type: .latest, now: now, user: .guest)

        #expect(result == [nextYearRoute])
        #expect(repository.queryByYearCallCount == 1)
        #expect(queriedYears == [2027])
        #expect(periodRepository.queryByYearCallCount == 2)
    }

    @Test
    func query_正常_latest_翌年Periodありで今年Routeを採用() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let now = SimpleDate(year: 2026, month: 2, day: 1)
        let currentYearRoute = Route.mock(id: "route-current", districtId: district.id)
        var queriedYears: [Int] = []

        let repository = RouteRepositoryMock(
            queryHandler: { _ in [] },
            queryByYearHandler: { _, year in
                queriedYears.append(year)
                if year == 2026 { return [currentYearRoute] }
                return []
            }
        )
        let periodRepository = PeriodRepositoryMock(queryByYearHandler: { _, year in
            if year == 2027 { return [Period.mock(id: "period-2027", festivalId: district.festivalId, date: .init(year: 2027, month: 1, day: 1))] }
            if year == 2026 { return [Period.mock(id: "period-2026", festivalId: district.festivalId, date: .init(year: 2026, month: 1, day: 1))] }
            return []
        })
        let subject = make(
            routeRepository: repository,
            periodRepository: periodRepository,
            districtRepository: .init(getHandler: { _ in district })
        )

        let result = try await subject.query(by: district.id, type: .latest, now: now, user: .guest)

        #expect(result == [currentYearRoute])
        #expect(repository.queryByYearCallCount == 2)
        #expect(queriedYears == [2027, 2026])
        #expect(periodRepository.queryByYearCallCount == 2)
    }

    @Test
    func query_正常_latest_翌年Periodなしで前年Routeを採用() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let lastYearRoute = Route.mock(id: "route-last", districtId: district.id)
        var queriedYears: [Int] = []

        let repository = RouteRepositoryMock(
            queryHandler: { _ in [] },
            queryByYearHandler: { _, year in
                queriedYears.append(year)
                if year == 2025 { return [lastYearRoute] }
                return []
            }
        )
        let periodRepository = PeriodRepositoryMock(queryByYearHandler: { _, year in
            if year == 2026 { return [Period.mock(id: "period-2026", festivalId: district.festivalId, date: .init(year: 2026, month: 1, day: 1))] }
            if year == 2025 { return [Period.mock(id: "period-2025", festivalId: district.festivalId, date: .init(year: 2025, month: 1, day: 1))] }
            return []
        })
        let subject = make(
            routeRepository: repository,
            periodRepository: periodRepository,
            districtRepository: .init(getHandler: { _ in district })
        )

        let result = try await subject.query(
            by: district.id,
            type: .latest,
            now: .init(year: 2026, month: 2, day: 1),
            user: .guest
        )

        #expect(result == [lastYearRoute])
        #expect(repository.queryByYearCallCount == 2)
        #expect(queriedYears == [2026, 2025])
        #expect(periodRepository.queryByYearCallCount == 3)
    }

    @Test
    func query_正常_latest_Periodなしは空配列() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let repository = RouteRepositoryMock(
            queryHandler: { _ in [] },
            queryByYearHandler: { _, _ in
                Issue.record("route query by year should not be called without periods")
                return []
            }
        )
        let periodRepository = PeriodRepositoryMock(queryByYearHandler: { _, _ in [] })
        let subject = make(
            routeRepository: repository,
            periodRepository: periodRepository,
            districtRepository: .init(getHandler: { _ in district })
        )

        let result = try await subject.query(
            by: district.id,
            type: .latest,
            now: .init(year: 2026, month: 2, day: 1),
            user: .guest
        )

        #expect(result.isEmpty)
        #expect(repository.queryByYearCallCount == 0)
        #expect(periodRepository.queryByYearCallCount == 3)
    }

    @Test
    func post_異常_権限不一致() async {
        let pack = RoutePack.mock(route: .mock(id: "route-1", districtId: "district-1"), points: [], passages: [])
        let subject = make()

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            _ = try await subject.post(districtId: "district-1", pack: pack, user: .guest)
        }
    }

    @Test
    func post_正常() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        var district = District.mock(id: route.districtId, festivalId: "festival-1")
        district.isEditable = false
        let points = [
            Point.mock(id: "p-1", routeId: route.id, index: 0, time: .init(hour: 9, minute: 0), anchor: .start),
            Point.mock(id: "p-2", routeId: route.id, index: 1, time: .init(hour: 10, minute: 0), anchor: .end)
        ]
        let passages = [RoutePassage.mock(id: "pa-1", routeId: route.id, districtId: route.districtId, order: 0)]
        let pack = RoutePack.mock(route: route, points: points, passages: passages)

        let routeRepository = RouteRepositoryMock(postHandler: { $0 })
        let pointRepository = PointRepositoryMock(queryHandler: { _ in [] }, postHandler: { $0 })
        let passageRepository = PassageRepositoryMock(queryHandler: { _ in [] }, postHandler: { $0 })
        let subject = make(
            routeRepository: routeRepository,
            districtRepository: .init(getHandler: { _ in district }),
            pointRepository: pointRepository,
            passageRepository: passageRepository
        )

        let result = try await subject.post(districtId: route.districtId, pack: pack, user: .district(route.districtId))

        #expect(result.route == route)
        #expect(result.points.count == 2)
        #expect(result.passages.count == 1)
        #expect(routeRepository.postCallCount == 1)
        #expect(pointRepository.postCallCount == 2)
        #expect(passageRepository.postCallCount == 1)
    }

    @Test
    func put_異常_ルート未登録() async {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let pack = RoutePack.mock(route: route, points: [], passages: [])
        let subject = make(
            routeRepository: .init(getHandler: { _ in nil })
        )

        await #expect(throws: Error.notFound("指定されたルートが見つかりません")) {
            _ = try await subject.put(id: route.id, pack: pack, user: .district(route.districtId))
        }
    }

    @Test
    func put_正常() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        var district = District.mock(id: route.districtId, festivalId: "festival-1")
        district.isEditable = false
        let points = [
            Point.mock(id: "p-1", routeId: route.id, index: 0, time: .init(hour: 9, minute: 0), anchor: .start),
            Point.mock(id: "p-2", routeId: route.id, index: 1, time: .init(hour: 10, minute: 0), anchor: .end)
        ]
        let pack = RoutePack.mock(route: route, points: points, passages: [])
        let routeRepository = RouteRepositoryMock(getHandler: { _ in route }, postHandler: { $0 })
        let pointRepository = PointRepositoryMock(queryHandler: { _ in [] }, postHandler: { $0 })
        let subject = make(
            routeRepository: routeRepository,
            districtRepository: .init(getHandler: { _ in district }),
            pointRepository: pointRepository,
            passageRepository: .init(queryHandler: { _ in [] })
        )

        let result = try await subject.put(id: route.id, pack: pack, user: .district(route.districtId))

        #expect(result.route == route)
        #expect(result.points.count == 2)
        #expect(routeRepository.getCallCount == 1)
        #expect(routeRepository.postCallCount == 1)
        #expect(pointRepository.postCallCount == 2)
    }

    @Test
    func delete_異常_権限不一致() async {
        let route = Route.mock(id: "route-1", districtId: "district-1", periodId: "period-1")

        let subject = make(
            routeRepository: .init(getHandler: { _ in route })
        )

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            try await subject.delete(id: route.id, user: .district("other"))
        }
    }

    @Test
    func delete_正常() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        var district = District.mock(id: route.districtId, festivalId: "festival-1")
        district.isEditable = false
        let routeRepository = RouteRepositoryMock(
            getHandler: { _ in route },
            deleteHandler: { _ in }
        )
        let pointRepository = PointRepositoryMock(deleteByRouteHandler: { _ in })
        let passageRepository = PassageRepositoryMock(deleteByRouteHandler: { _ in })

        let subject = make(
            routeRepository: routeRepository,
            districtRepository: .init(getHandler: { _ in district }),
            pointRepository: pointRepository,
            passageRepository: passageRepository
        )

        try await subject.delete(id: route.id, user: .district(route.districtId))

        #expect(routeRepository.deleteCallCount == 1)
        #expect(pointRepository.deleteByRouteCallCount == 1)
        #expect(passageRepository.deleteByRouteCallCount == 1)
    }

    @Test
    func post_異常_本部編集中で更新禁止() async {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let district = District.mock(id: route.districtId, festivalId: "festival-1")
        let festival = Festival.mock(id: district.festivalId, subname: "祭本部")
        let pack = RoutePack.mock(route: route, points: [], passages: [])
        let subject = make(
            districtRepository: .init(getHandler: { _ in
                var item = district
                item.isEditable = true
                return item
            }),
            festivalRepository: .init(getHandler: { _ in festival })
        )

        await #expect(throws: Error.forbidden("祭本部編集中のためRoute更新はできません")) {
            _ = try await subject.post(districtId: route.districtId, pack: pack, user: .district(route.districtId))
        }
    }

    @Test
    func put_異常_本部編集中で更新禁止() async {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let district = District.mock(id: route.districtId, festivalId: "festival-1")
        let festival = Festival.mock(id: district.festivalId, subname: "祭本部")
        let pack = RoutePack.mock(route: route, points: [], passages: [])
        let subject = make(
            routeRepository: .init(getHandler: { _ in route }),
            districtRepository: .init(getHandler: { _ in
                var item = district
                item.isEditable = true
                return item
            }),
            festivalRepository: .init(getHandler: { _ in festival })
        )

        await #expect(throws: Error.forbidden("祭本部編集中のためRoute更新はできません")) {
            _ = try await subject.put(id: route.id, pack: pack, user: .district(route.districtId))
        }
    }

    @Test
    func delete_異常_本部編集中で更新禁止() async {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let district = District.mock(id: route.districtId, festivalId: "festival-1")
        let festival = Festival.mock(id: district.festivalId, subname: "祭本部")
        let subject = make(
            routeRepository: .init(getHandler: { _ in route }),
            districtRepository: .init(getHandler: { _ in
                var item = district
                item.isEditable = true
                return item
            }),
            festivalRepository: .init(getHandler: { _ in festival })
        )

        await #expect(throws: Error.forbidden("祭本部編集中のためRoute更新はできません")) {
            try await subject.delete(id: route.id, user: .district(route.districtId))
        }
    }

    @Test
    func query_異常_依存エラーを透過() async {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let subject = make(
            routeRepository: .init(queryHandler: { _ in throw TestError.intentional }),
            districtRepository: .init(getHandler: { _ in district })
        )

        await #expect(throws: TestError.intentional) {
            _ = try await subject.query(
                by: "district-1",
                type: .all,
                now: .init(year: 2026, month: 2, day: 22),
                user: .guest
            )
        }
    }
}

private extension RouteUsecaseTest {
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
