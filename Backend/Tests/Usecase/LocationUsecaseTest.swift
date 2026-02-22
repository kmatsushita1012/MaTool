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
    func query_outsidePublicPeriod_districtGetsOwnLocation() async throws {
        let location = FloatLocation.mock(id: "loc-1", districtId: "district-1")
        let repository = LocationRepositoryMock(getHandler: { _, _ in location })
        let subject = make(
            locationRepository: repository,
            districtRepository: .init(),
            periodRepository: .init(queryByYearHandler: { _, _ in [] })
        )

        let result = try await subject.query(by: "festival-1", user: .district("district-1"), now: now)

        #expect(result == [location])
        #expect(repository.getCallCount == 1)
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
    func get_districtNotFound_throws() async {
        let subject = make(
            locationRepository: .init(),
            districtRepository: .init(getHandler: { _ in nil }),
            periodRepository: .init()
        )

        await #expect(throws: Error.notFound("指定された地区が見つかりません")) {
            _ = try await subject.get(districtId: "district-missing", user: .guest, now: now)
        }
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

    @Test
    func put_authorized_updatesLocation() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let location = FloatLocation.mock(id: "loc-1", districtId: district.id)
        var capturedFestivalId: String?
        let repository = LocationRepositoryMock(putHandler: { item, festivalId in
            capturedFestivalId = festivalId
            return item
        })

        let subject = make(
            locationRepository: repository,
            districtRepository: .init(getHandler: { _ in district }),
            periodRepository: .init()
        )

        let result = try await subject.put(location, user: .district(district.id))

        #expect(result == location)
        #expect(capturedFestivalId == district.festivalId)
        #expect(repository.putCallCount == 1)
    }

    @Test
    func delete_authorized_deletesLocation() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        var capturedFestivalId: String?
        var capturedDistrictId: String?

        let subject = make(
            locationRepository: .init(deleteHandler: { festivalId, districtId in
                capturedFestivalId = festivalId
                capturedDistrictId = districtId
            }),
            districtRepository: .init(getHandler: { _ in district }),
            periodRepository: .init()
        )

        try await subject.delete(districtId: district.id, user: .district(district.id))

        #expect(capturedFestivalId == district.festivalId)
        #expect(capturedDistrictId == district.id)
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
