import Dependencies
import Shared
import Testing
@testable import Backend

struct DistrictUsecaseTest {
    @Test
    func query_forwardsToRepository() async throws {
        let districts = [District.mock(id: "district-1", festivalId: "festival-1")]
        let repository = DistrictRepositoryMock(queryHandler: { _ in districts })
        let subject = make(
            districtRepository: repository,
            festivalRepository: .init(),
            performanceRepository: .init(),
            authManagerFactory: { throw TestError.unimplemented }
        )

        let result = try await subject.query(by: "festival-1")

        #expect(result == districts)
        #expect(repository.queryCallCount == 1)
    }

    @Test
    func get_returnsDistrictPack() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let performances = [Performance.mock(id: "perf-1", districtId: district.id)]

        let subject = make(
            districtRepository: .init(getHandler: { _ in district }),
            festivalRepository: .init(),
            performanceRepository: .init(queryHandler: { _ in performances }),
            authManagerFactory: { throw TestError.unimplemented }
        )

        let result = try await subject.get(district.id)

        #expect(result.district == district)
        #expect(result.performances == performances)
    }

    @Test
    func post_unauthorized_throws() async {
        let subject = make(
            districtRepository: .init(),
            festivalRepository: .init(),
            performanceRepository: .init(),
            authManagerFactory: { throw TestError.unimplemented }
        )

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
    func post_createsDistrictWithGeneratedId() async throws {
        let festival = Festival.mock(id: "festival_2026")
        let expectedDistrictId = "festival_new"
        var posted: District?

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
                #expect(id == festival.id)
                return festival
            }),
            performanceRepository: .init(),
            authManagerFactory: { manager }
        )

        let result = try await subject.post(
            user: .headquarter(festival.id),
            headquarterId: festival.id,
            newDistrictName: "new",
            email: "district@example.com"
        )

        #expect(manager.createCallCount == 1)
        #expect(posted?.id == expectedDistrictId)
        #expect(result.district.id == expectedDistrictId)
        #expect(result.performances.isEmpty)
    }

    @Test
    func put_districtRole_onlyAllowsLimitedFields() async throws {
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

        let subject = make(
            districtRepository: .init(
                getHandler: { _ in current },
                putHandler: { _, item in
                    merged = item
                    return item
                }
            ),
            festivalRepository: .init(),
            performanceRepository: .init(queryHandler: { _ in [] }),
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
    }

    @Test
    func put_headquarterRole_onlyAllowsCoreFields() async throws {
        let current = District.mock(id: "district-1", festivalId: "festival-1", name: "old", visibility: .all)
        var incoming = District.mock(id: current.id, festivalId: current.festivalId, name: "new", visibility: .admin)
        incoming.order = 5
        incoming.group = "B"
        incoming.isEditable = false
        var merged: District?

        let subject = make(
            districtRepository: .init(
                getHandler: { _ in current },
                putHandler: { _, item in
                    merged = item
                    return item
                }
            ),
            festivalRepository: .init(),
            performanceRepository: .init(),
            authManagerFactory: { throw TestError.unimplemented }
        )

        let result = try await subject.put(id: current.id, district: incoming, user: .headquarter(current.festivalId))

        #expect(merged?.name == "old")
        #expect(merged?.visibility == .all)
        #expect(merged?.order == 5)
        #expect(merged?.group == "B")
        #expect(merged?.isEditable == false)
        #expect(result.order == 5)
    }
}

private extension DistrictUsecaseTest {
    func make(
        districtRepository: DistrictRepositoryMock,
        festivalRepository: FestivalRepositoryMock,
        performanceRepository: PerformanceRepositoryMock,
        authManagerFactory: @escaping AuthManagerFactory
    ) -> DistrictUsecase {
        withDependencies {
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[FestivalRepositoryKey.self] = festivalRepository
            $0[PerformanceRepositoryKey.self] = performanceRepository
            $0[AuthManagerFactoryKey.self] = authManagerFactory
        } operation: {
            DistrictUsecase()
        }
    }
}
