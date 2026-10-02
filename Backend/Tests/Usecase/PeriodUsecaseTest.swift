import Dependencies
import Shared
import Testing
@testable import Backend

struct PeriodUsecaseTest {
    @Test
    func get_正常() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1")
        let repository = PeriodRepositoryMock(getHandler: { _ in period })
        let subject = make(repository: repository)

        let result = try await subject.get(id: period.id)

        #expect(result == period)
        #expect(repository.getCallCount == 1)
    }

    @Test
    func get_異常_日程未登録() async {
        let subject = make(repository: .init(getHandler: { _ in nil }))

        await #expect(throws: Error.notFound("指定された日程が取得できませんでした。")) {
            _ = try await subject.get(id: "period-missing")
        }
    }

    @Test
    func queryByYear_正常() async throws {
        let periods = [Period.mock(id: "period-1", festivalId: "festival-1", date: .init(year: 2026, month: 2, day: 22))]
        let repository = PeriodRepositoryMock(queryByYearHandler: { _, _ in periods })

        let subject = make(repository: repository)
        let result = try await subject.query(by: "festival-1", year: 2026)

        #expect(result == periods)
        #expect(repository.queryByYearCallCount == 1)
    }

    @Test
    func query_正常() async throws {
        let periods = [Period.mock(id: "period-2", festivalId: "festival-1")]
        let repository = PeriodRepositoryMock(queryHandler: { _ in periods })
        let subject = make(repository: repository)

        let result = try await subject.query(by: "festival-1")

        #expect(result == periods)
        #expect(repository.queryCallCount == 1)
    }

    @Test
    func post_異常_権限不一致() async {
        let period = Period.mock(festivalId: "festival-1")
        let subject = make()

        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            _ = try await subject.post(festivalId: "festival-1", period: period, user: .guest)
        }
    }

    @Test
    func post_正常() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1")
        let repository = PeriodRepositoryMock(postHandler: { $0 })
        let subject = make(repository: repository)

        let result = try await subject.post(festivalId: "festival-1", period: period, user: .headquarter("festival-1"))

        #expect(result == period)
        #expect(repository.postCallCount == 1)
    }

    @Test
    func put_正常() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1")
        let repository = PeriodRepositoryMock(putHandler: { $0 })
        let subject = make(repository: repository)

        let result = try await subject.put(period: period, user: .headquarter("festival-1"))

        #expect(result == period)
        #expect(repository.putCallCount == 1)
    }

    @Test
    func delete_正常() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1", date: .init(year: 2026, month: 2, day: 22), start: .init(hour: 10, minute: 0))
        var lastCalledFestivalId: String?

        let repository = PeriodRepositoryMock(
            getHandler: { _ in period },
            deleteHandler: { festivalId, _, _ in
                lastCalledFestivalId = festivalId
            }
        )
        let subject = make(repository: repository)

        try await subject.delete(id: period.id, user: .headquarter("festival-1"))

        #expect(repository.deleteCallCount == 1)
        #expect(lastCalledFestivalId == "festival-1")
    }

    @Test
    func delete_正常_関連Routeと地点通過先を削除する() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1")
        let firstDistrict = District.mock(id: "district-1", festivalId: period.festivalId)
        let secondDistrict = District.mock(id: "district-2", festivalId: period.festivalId)
        let matchingRoute = Route.mock(id: "route-1", districtId: firstDistrict.id, periodId: period.id)
        let unrelatedRoute = Route.mock(id: "route-2", districtId: firstDistrict.id, periodId: "another-period")
        let secondMatchingRoute = Route.mock(id: "route-3", districtId: secondDistrict.id, periodId: period.id)
        var deletedRouteIDs: [String] = []
        var deletedPointRouteIDs: [String] = []
        var deletedPassageRouteIDs: [String] = []
        var periodWasDeleted = false

        let periodRepository = PeriodRepositoryMock(
            getHandler: { _ in period },
            deleteHandler: { _, _, _ in periodWasDeleted = true }
        )
        let districtRepository = DistrictRepositoryMock(
            queryHandler: { _ in [firstDistrict, secondDistrict] }
        )
        let routeRepository = RouteRepositoryMock(
            queryHandler: { districtId in
                districtId == firstDistrict.id
                    ? [matchingRoute, unrelatedRoute]
                    : [secondMatchingRoute]
            },
            deleteRouteHandler: { route in deletedRouteIDs.append(route.id) }
        )
        let pointRepository = PointRepositoryMock(
            deleteByRouteHandler: { routeId in deletedPointRouteIDs.append(routeId) }
        )
        let passageRepository = PassageRepositoryMock(
            deleteByRouteHandler: { routeId in deletedPassageRouteIDs.append(routeId) }
        )
        let subject = make(
            repository: periodRepository,
            districtRepository: districtRepository,
            routeRepository: routeRepository,
            pointRepository: pointRepository,
            passageRepository: passageRepository
        )

        try await subject.delete(id: period.id, user: .headquarter(period.festivalId))

        #expect(deletedRouteIDs == [matchingRoute.id, secondMatchingRoute.id])
        #expect(deletedPointRouteIDs == [matchingRoute.id, secondMatchingRoute.id])
        #expect(deletedPassageRouteIDs == [matchingRoute.id, secondMatchingRoute.id])
        #expect(periodWasDeleted)
    }

    @Test
    func query_異常_依存エラーを透過() async {
        let subject = make(repository: .init(queryHandler: { _ in throw TestError.intentional }))

        await #expect(throws: TestError.intentional) {
            _ = try await subject.query(by: "festival-1")
        }
    }
}

private extension PeriodUsecaseTest {
    func make(
        repository: PeriodRepositoryMock = .init(),
        districtRepository: DistrictRepositoryMock = .init(queryHandler: { _ in [] }),
        routeRepository: RouteRepositoryMock = .init(queryHandler: { _ in [] }),
        pointRepository: PointRepositoryMock = .init(),
        passageRepository: PassageRepositoryMock = .init()
    ) -> PeriodUsecase {
        withDependencies {
            $0[PeriodRepositoryKey.self] = repository
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[RouteRepositoryKey.self] = routeRepository
            $0[PointRepositoryKey.self] = pointRepository
            $0[PassageRepositoryKey.self] = passageRepository
        } operation: {
            PeriodUsecase()
        }
    }
}
