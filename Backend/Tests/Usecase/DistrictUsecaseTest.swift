import Dependencies
import Shared
import Testing
@testable import Backend

@Suite(.serialized)
struct DistrictUsecaseTest {
    @Test
    func query_正常() async throws {
        let districts = [District.mock(id: "district-1", festivalId: "festival-1")]
        let repository = DistrictRepositoryMock(queryHandler: { _ in districts })
        let subject = make(
            districtRepository: repository
        )

        let result = try await subject.query(by: "festival-1")

        #expect(result == districts)
        #expect(repository.queryCallCount == 1)
    }

    @Test
    func get_正常() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let performances = [Performance.mock(id: "perf-1", districtId: district.id)]
        var lastCalledDistrictId: String?
        let districtRepository = DistrictRepositoryMock(getHandler: { id in
            lastCalledDistrictId = id
            return district
        })
        let performanceRepository = PerformanceRepositoryMock(queryHandler: { _ in performances })

        let subject = make(
            districtRepository: districtRepository,
            performanceRepository: performanceRepository,
            authManagerFactory: { throw TestError.unimplemented }
        )

        let result = try await subject.get(district.id)

        #expect(result.district == district)
        #expect(result.performances == performances)
        #expect(lastCalledDistrictId == district.id)
        #expect(districtRepository.getCallCount == 1)
        #expect(performanceRepository.queryCallCount == 1)
    }

    @Test
    func post_異常_権限不一致() async {
        let subject = make()

        await #expect(throws: Error.unauthorized()) {
            _ = try await subject.post(
                user: .guest,
                headquarterId: "festival-1",
                newDistrictName: "new",
                email: "a@example.com"
            )
        }
    }

    @Test
    func post_正常() async throws {
        let festival = Festival.mock(id: "festival_2026")
        let expectedDistrictId = "festival_new"
        var posted: District?
        var lastCalledFestivalId: String?

        let manager = AuthManagerMock(
            createHandler: { username, _ in
                #expect(username == expectedDistrictId)
                return .district(username)
            }
        )

        let subject = make(
            districtRepository: .init(
                getHandler: { id in
                    if id == festival.id { return District.mock(id: "ignored", festivalId: festival.id) /* unused */ }
                    return nil
                },
                postHandler: { item in
                    posted = item
                    return item
                }
            ),
            festivalRepository: .init(getHandler: { id in
                lastCalledFestivalId = id
                #expect(id == festival.id)
                return festival
            }),
            authManagerFactory: { manager }
        )

        let result = try await subject.post(
            user: .headquarter(festival.id),
            headquarterId: festival.id,
            newDistrictName: "new",
            email: "district@example.com"
        )

        #expect(manager.createCallCount == 1)
        #expect(lastCalledFestivalId == festival.id)
        #expect(posted?.id == expectedDistrictId)
        #expect(result.district.id == expectedDistrictId)
        #expect(result.performances.isEmpty)
    }

    @Test
    func put_正常_地区権限は編集可能項目のみ反映() async throws {
        let nowYear = SimpleDate.now.year
        let current = District(
            id: "district-1",
            name: "old",
            festivalId: "festival-1",
            order: 9,
            group: "A",
            description: "old desc",
            base: .init(latitude: 35, longitude: 139),
            area: [.init(latitude: 35, longitude: 139)],
            image: .init(light: "old.png", dark: nil),
            visibility: .all,
            isEditable: false
        )
        let incoming = District(
            id: "district-1",
            name: "new",
            festivalId: "festival-1",
            order: 1,
            group: "B",
            description: "new desc",
            base: .init(latitude: 36, longitude: 140),
            area: [.init(latitude: 36, longitude: 140)],
            image: .init(light: "new.png", dark: nil),
            visibility: .admin,
            isEditable: true
        )
        var merged: District?
        var lastCalledGetId: String?
        var lastCalledPutId: String?
        var updatedRoutes: [Route] = []
        let districtRepository = DistrictRepositoryMock(
            getHandler: { id in
                lastCalledGetId = id
                return current
            },
            putHandler: { id, item in
                lastCalledPutId = id
                merged = item
                return item
            }
        )
        let performanceRepository = PerformanceRepositoryMock(queryHandler: { _ in [] })
        let currentYearPeriod = Period.mock(id: "period-\(nowYear)", festivalId: current.festivalId, date: .init(year: nowYear, month: 1, day: 1))
        let lastYearPeriod = Period.mock(id: "period-\(nowYear - 1)", festivalId: current.festivalId, date: .init(year: nowYear - 1, month: 1, day: 1))
        let periodRepository = PeriodRepositoryMock(queryByYearHandler: { _, year in
            if year == nowYear + 1 { return [] }
            if year == nowYear { return [currentYearPeriod] }
            if year == nowYear - 1 { return [lastYearPeriod] }
            return []
        })
        let routeRepository = RouteRepositoryMock(
            queryByYearHandler: { _, year in
                guard year == nowYear else { return [] }
                return [
                    Route.mock(id: "route-1", districtId: current.id, periodId: currentYearPeriod.id, visibility: .all),
                    Route.mock(id: "route-2", districtId: current.id, periodId: currentYearPeriod.id, visibility: .route),
                ]
            },
            putHandler: {
                updatedRoutes.append($0)
                return $0
            }
        )

        let subject = make(
            districtRepository: districtRepository,
            routeRepository: routeRepository,
            periodRepository: periodRepository,
            performanceRepository: performanceRepository,
            authManagerFactory: { throw TestError.unimplemented }
        )

        let result = try await subject.put(
            id: current.id,
            item: .mock(district: incoming, performances: []),
            user: .district(current.id)
        )

        #expect(merged?.name == "new")
        #expect(merged?.description == "new desc")
        #expect(merged?.visibility == .admin)
        #expect(merged?.order == 9)
        #expect(merged?.group == "A")
        #expect(merged?.isEditable == false)
        #expect(result.district.order == 9)
        #expect(result.district.name == "new")
        #expect(lastCalledGetId == current.id)
        #expect(lastCalledPutId == current.id)
        #expect(districtRepository.getCallCount == 1)
        #expect(districtRepository.putCallCount == 1)
        #expect(periodRepository.queryByYearCallCount == 3)
        #expect(routeRepository.queryByYearCallCount == 1)
        #expect(routeRepository.putCallCount == 2)
        #expect(updatedRoutes.count == 2)
        #expect(updatedRoutes.allSatisfy { $0.visibility == .admin })
        #expect(performanceRepository.queryCallCount == 1)
    }

    @Test
    func put_正常_地区権限_visibility不変ならRoute更新しない() async throws {
        let current = District.mock(id: "district-1", festivalId: "festival-1", visibility: .route)
        let incoming = District.mock(id: "district-1", festivalId: "festival-1", visibility: .route)

        let districtRepository = DistrictRepositoryMock(
            getHandler: { _ in current },
            putHandler: { _, _ in incoming }
        )
        let routeRepository = RouteRepositoryMock(
            queryByYearHandler: { _, _ in
                Issue.record("route queryByYear should not be called when visibility is unchanged")
                return []
            },
            putHandler: { route in
                Issue.record("route put should not be called when visibility is unchanged: \(route.id)")
                return route
            }
        )

        let subject = make(
            districtRepository: districtRepository,
            routeRepository: routeRepository,
            periodRepository: .init(queryByYearHandler: { _, _ in [] }),
            performanceRepository: .init(queryHandler: { _ in [] }),
            authManagerFactory: { throw TestError.unimplemented }
        )

        _ = try await subject.put(
            id: current.id,
            item: .mock(district: incoming, performances: []),
            user: .district(current.id)
        )

        #expect(routeRepository.queryByYearCallCount == 0)
        #expect(routeRepository.putCallCount == 0)
    }

    @Test
    func put_正常_本部権限は管理項目のみ反映() async throws {
        let current = District.mock(id: "district-1", festivalId: "festival-1", name: "old", visibility: .all)
        var incoming = District.mock(id: current.id, festivalId: current.festivalId, name: "new", visibility: .admin)
        incoming.order = 5
        incoming.group = "B"
        incoming.isEditable = false
        var merged: District?
        var lastCalledGetId: String?
        var lastCalledPutId: String?
        let districtRepository = DistrictRepositoryMock(
            getHandler: { id in
                lastCalledGetId = id
                return current
            },
            putHandler: { id, item in
                lastCalledPutId = id
                merged = item
                return item
            }
        )

        let subject = make(
            districtRepository: districtRepository,
            authManagerFactory: { throw TestError.unimplemented }
        )

        let result = try await subject.put(id: current.id, district: incoming, user: .headquarter(current.festivalId))

        #expect(merged?.name == "old")
        #expect(merged?.visibility == .all)
        #expect(merged?.order == 5)
        #expect(merged?.group == "B")
        #expect(merged?.isEditable == false)
        #expect(result.order == 5)
        #expect(result.id == current.id)
        #expect(lastCalledGetId == current.id)
        #expect(lastCalledPutId == current.id)
        #expect(districtRepository.getCallCount == 1)
        #expect(districtRepository.putCallCount == 1)
    }

    @Test
    func query_異常_依存エラーを透過() async {
        let subject = make(
            districtRepository: .init(queryHandler: { _ in throw TestError.intentional }),
            authManagerFactory: { throw TestError.unimplemented }
        )

        await #expect(throws: TestError.intentional) {
            _ = try await subject.query(by: "festival-1")
        }
    }
}

private extension DistrictUsecaseTest {
    func make(
        districtRepository: DistrictRepositoryMock = .init(),
        routeRepository: RouteRepositoryMock = .init(),
        periodRepository: PeriodRepositoryMock = .init(),
        festivalRepository: FestivalRepositoryMock = .init(),
        performanceRepository: PerformanceRepositoryMock = .init(),
        authManagerFactory: @escaping AuthManagerFactory = { throw TestError.unimplemented }
    ) -> DistrictUsecase {
        withDependencies {
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[RouteRepositoryKey.self] = routeRepository
            $0[PeriodRepositoryKey.self] = periodRepository
            $0[FestivalRepositoryKey.self] = festivalRepository
            $0[PerformanceRepositoryKey.self] = performanceRepository
            $0[AuthManagerFactoryKey.self] = authManagerFactory
        } operation: {
            DistrictUsecase()
        }
    }
}
