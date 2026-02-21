import Dependencies
import Shared
import Testing
@testable import Backend

struct DistrictUsecaseTest {
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
