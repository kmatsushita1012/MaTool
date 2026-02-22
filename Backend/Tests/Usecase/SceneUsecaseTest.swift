import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct SceneUsecaseTest {
    @Test
    func fetchLaunchFestivalPack_正常_ゲストは公開情報のみ取得() async throws {
        let now = makeDate(year: 2026, month: 2, day: 22, hour: 12)
        let festival = Festival.mock(id: "festival-1")
        let districts = [District.mock(id: "district-1", festivalId: festival.id)]

        let festivalRepository = FestivalRepositoryMock(getHandler: { _ in festival })
        let districtRepository = DistrictRepositoryMock(queryHandler: { _ in districts })
        let subject = make(
            festivalRepository: festivalRepository,
            districtRepository: districtRepository,
            periodRepository: .init(queryByYearHandler: { _, _ in [] })
        )

        let result = try await subject.fetchLaunchFestivalPack(festivalId: festival.id, user: .guest, now: now)

        #expect(result.festival == festival)
        #expect(result.districts == districts)
        #expect(result.locations.isEmpty)
        #expect(result.checkpoints.isEmpty)
        #expect(result.hazardSections.isEmpty)
        #expect(festivalRepository.getCallCount == 1)
        #expect(districtRepository.queryCallCount == 1)
    }

    @Test
    func fetchLaunchFestivalPack_正常_本部権限は全情報取得() async throws {
        let now = makeDate(year: 2026, month: 2, day: 22, hour: 12)
        let festival = Festival.mock(id: "festival-1")
        let districts = [District.mock(id: "district-1", festivalId: festival.id)]
        let period = Period.mock(id: "period-1", festivalId: festival.id, date: .from(now), start: .init(hour: 9, minute: 0), end: .init(hour: 13, minute: 0))
        let location = FloatLocation.mock(id: "loc-1", districtId: "district-1")
        let checkpoint = Checkpoint.mock(id: "cp-1", festivalId: festival.id)
        let hazard = HazardSection.mock(id: "hz-1", festivalId: festival.id)

        let festivalRepository = FestivalRepositoryMock(getHandler: { _ in festival })
        let districtRepository = DistrictRepositoryMock(queryHandler: { _ in districts })
        let subject = make(
            festivalRepository: festivalRepository,
            districtRepository: districtRepository,
            periodRepository: .init(queryHandler: { _ in [period] }),
            locationRepository: .init(queryHandler: { _ in [location] }),
            checkpointRepository: .init(queryHandler: { _ in [checkpoint] }),
            hazardRepository: .init(queryHandler: { _ in [hazard] })
        )

        let result = try await subject.fetchLaunchFestivalPack(festivalId: festival.id, user: .headquarter(festival.id), now: now)

        #expect(result.periods == [period])
        #expect(result.locations == [location])
        #expect(result.checkpoints == [checkpoint])
        #expect(result.hazardSections == [hazard])
        #expect(festivalRepository.getCallCount == 1)
        #expect(districtRepository.queryCallCount == 1)
    }

    @Test
    func fetchLaunchFestivalPack_異常_地区未登録() async {
        let subject = make(
            districtRepository: .init(getHandler: { _ in nil })
        )

        await #expect(throws: Error.notFound("District district-missing が見つかりません")) {
            _ = try await subject.fetchLaunchFestivalPack(districtId: "district-missing", user: .guest, now: .now)
        }
    }

    @Test
    func fetchLaunchDistrictPack_正常_地区権限は非公開ルート取得() async throws {
        let now = makeDate(year: 2026, month: 2, day: 22, hour: 12)
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let period = Period.mock(id: "period-1", festivalId: district.festivalId, date: .from(now), start: .init(hour: 11, minute: 0), end: .init(hour: 13, minute: 0))
        let route = Route.mock(id: "route-1", districtId: district.id, periodId: period.id, visibility: .admin)
        let point = Point.mock(id: "point-1", routeId: route.id)
        let passage = RoutePassage.mock(id: "passage-1", routeId: route.id, districtId: district.id)

        let routeRepository = RouteRepositoryMock(queryHandler: { _ in [route] })
        let pointRepository = PointRepositoryMock(queryHandler: { _ in [point] })
        let passageRepository = PassageRepositoryMock(queryHandler: { _ in [passage] })

        let subject = make(
            districtRepository: .init(getHandler: { _ in district }),
            periodRepository: .init(queryByYearHandler: { _, _ in [period] }),
            performanceRepository: .init(queryHandler: { _ in [] }),
            routeRepository: routeRepository,
            pointRepository: pointRepository,
            passageRepository: passageRepository
        )

        let result = try await subject.fetchLaunchDistrictPack(districtId: district.id, user: .district(district.id), now: now)

        #expect(result.routes == [route])
        #expect(result.currentRouteId == route.id)
        #expect(result.points == [point])
        #expect(result.passages == [passage])
        #expect(routeRepository.queryCallCount == 1)
    }

    @Test
    func fetchLaunchDistrictPack_正常_ゲストは非公開ルート除外() async throws {
        let now = makeDate(year: 2026, month: 2, day: 22, hour: 12)
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let period = Period.mock(id: "period-1", festivalId: district.festivalId, date: .from(now), start: .init(hour: 11, minute: 0), end: .init(hour: 13, minute: 0))
        let adminRoute = Route.mock(id: "route-1", districtId: district.id, periodId: period.id, visibility: .admin)
        let routeRepository = RouteRepositoryMock(queryByYearHandler: { _, _ in [adminRoute] })
        let pointRepository = PointRepositoryMock(queryHandler: { _ in
            Issue.record("points should not be queried when route is filtered")
            return []
        })
        let passageRepository = PassageRepositoryMock(queryHandler: { _ in
            Issue.record("passages should not be queried when route is filtered")
            return []
        })

        let subject = make(
            districtRepository: .init(getHandler: { _ in district }),
            periodRepository: .init(queryByYearHandler: { _, _ in [period] }),
            performanceRepository: .init(queryHandler: { _ in [] }),
            routeRepository: routeRepository,
            pointRepository: pointRepository,
            passageRepository: passageRepository
        )

        let result = try await subject.fetchLaunchDistrictPack(districtId: district.id, user: .guest, now: now)

        #expect(result.routes.isEmpty)
        #expect(result.currentRouteId == nil)
        #expect(result.points.isEmpty)
        #expect(result.passages.isEmpty)
        #expect(result.performances.isEmpty)
        #expect(routeRepository.queryByYearCallCount == 1)
        #expect(pointRepository.queryCallCount == 0)
        #expect(passageRepository.queryCallCount == 0)
    }

    @Test
    func fetchLaunchDistrictPack_異常_依存エラーを透過() async {
        let subject = make(
            districtRepository: .init(getHandler: { _ in .mock(id: "district-1", festivalId: "festival-1") }),
            periodRepository: .init(queryByYearHandler: { _, _ in [.mock(festivalId: "festival-1")] }),
            routeRepository: .init(queryHandler: { _ in throw TestError.intentional })
        )

        await #expect(throws: TestError.intentional) {
            _ = try await subject.fetchLaunchDistrictPack(
                districtId: "district-1",
                user: .district("district-1"),
                now: makeDate(year: 2026, month: 2, day: 22, hour: 12)
            )
        }
    }
}

private extension SceneUsecaseTest {
    func make(
        festivalRepository: FestivalRepositoryMock = .init(),
        districtRepository: DistrictRepositoryMock = .init(),
        periodRepository: PeriodRepositoryMock = .init(),
        locationRepository: LocationRepositoryMock = .init(),
        checkpointRepository: CheckpointRepositoryMock = .init(),
        hazardRepository: HazardSectionRepositoryMock = .init(),
        performanceRepository: PerformanceRepositoryMock = .init(),
        routeRepository: RouteRepositoryMock = .init(),
        pointRepository: PointRepositoryMock = .init(),
        passageRepository: PassageRepositoryMock = .init()
    ) -> SceneUsecase {
        withDependencies {
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
        } operation: {
            SceneUsecase()
        }
    }
}
