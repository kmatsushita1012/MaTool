import Foundation
import Dependencies
import Shared
import Testing
@testable import Backend

struct LocationUsecaseTest {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func query_publicPeriod_returnsAllLocations() async throws {
        let festivalId = "festival-1"
        let districtId = "district-1"
        let location = FloatLocation(id: "loc-1", districtId: districtId, coordinate: .init(latitude: 35, longitude: 139), timestamp: now)
        let period = Period(festivalId: festivalId, date: .from(now), start: .init(hour: 0, minute: 0), end: .init(hour: 23, minute: 59))

        let subject = make(
            locationRepository: .init(queryHandler: { _ in [location] }),
            districtRepository: .init(),
            periodRepository: .init(queryByYearHandler: { _, _ in [period] })
        )

        let result = try await subject.query(by: festivalId, user: UserRole.guest, now: now)

        #expect(result == [location])
    }

    @Test
    func query_outsidePublicPeriod_guestReturnsEmpty() async throws {
        let subject = make(
            locationRepository: .init(queryHandler: { _ in
                Issue.record("query should not be called when non-public")
                return []
            }),
            districtRepository: .init(),
            periodRepository: .init(queryByYearHandler: { _, _ in [] })
        )

        let result = try await subject.query(by: "festival-1", user: .guest, now: now)

        #expect(result.isEmpty)
    }

    @Test
    func get_outsidePublicPeriod_guestReturnsNil() async throws {
        let district = District(id: "district-1", name: "d", festivalId: "festival-1", visibility: .all)

        let subject = make(
            locationRepository: .init(getHandler: { _, _ in
                Issue.record("get should not be called when non-public")
                return nil
            }),
            districtRepository: .init(getHandler: { _ in district }),
            periodRepository: .init(queryByYearHandler: { _, _ in [] })
        )

        let result = try await subject.get(districtId: district.id, user: .guest, now: now)

        #expect(result == nil)
    }

    @Test
    func put_userMismatch_throwsUnauthorized() async {
        let location = FloatLocation(id: "loc-2", districtId: "district-1", coordinate: .init(latitude: 35, longitude: 139), timestamp: now)

        let subject = make(
            locationRepository: .init(),
            districtRepository: .init(),
            periodRepository: .init()
        )

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            _ = try await subject.put(location, user: .district("other"))
        }
    }
}

private extension LocationUsecaseTest {
    func make(
        locationRepository: LocationRepositoryMock,
        districtRepository: DistrictRepositoryMock,
        periodRepository: PeriodRepositoryMock
    ) -> LocationUsecase {
        withDependencies {
            $0[LocationRepositoryKey.self] = locationRepository
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[PeriodRepositoryKey.self] = periodRepository
        } operation: {
            LocationUsecase()
        }
    }
}
