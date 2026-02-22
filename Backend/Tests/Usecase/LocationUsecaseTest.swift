import Foundation
import Dependencies
import Shared
import Testing
@testable import Backend

struct LocationUsecaseTest {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func query_正常_条件1() async throws {
        let festivalId = "festival-1"
        let districtId = "district-1"
        let location = FloatLocation(id: "loc-1", districtId: districtId, coordinate: .init(latitude: 35, longitude: 139), timestamp: now)
        let period = Period(festivalId: festivalId, date: .from(now), start: .init(hour: 0, minute: 0), end: .init(hour: 23, minute: 59))
        let repository = LocationRepositoryMock(queryHandler: { _ in [location] })

        let subject = make(
            locationRepository: repository,
            districtRepository: .init(),
            periodRepository: .init(queryByYearHandler: { _, _ in [period] })
        )

        let result = try await subject.query(by: festivalId, user: UserRole.guest, now: now)

        #expect(result == [location])
        #expect(repository.queryCallCount == 1)
    }

    @Test
    func query_正常_条件2() async throws {
        let repository = LocationRepositoryMock(queryHandler: { _ in
            Issue.record("query should not be called when non-public")
            return []
        })
        let subject = make(
            locationRepository: repository,
            districtRepository: .init(),
            periodRepository: .init(queryByYearHandler: { _, _ in [] })
        )

        let result = try await subject.query(by: "festival-1", user: .guest, now: now)

        #expect(result.isEmpty)
        #expect(repository.queryCallCount == 0)
    }

    @Test
    func query_正常_条件3() async throws {
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
    func get_正常() async throws {
        let district = District(id: "district-1", name: "d", festivalId: "festival-1", visibility: .all)
        let repository = LocationRepositoryMock(getHandler: { _, _ in
            Issue.record("get should not be called when non-public")
            return nil
        })

        let subject = make(
            locationRepository: repository,
            districtRepository: .init(getHandler: { _ in district }),
            periodRepository: .init(queryByYearHandler: { _, _ in [] })
        )

        let result = try await subject.get(districtId: district.id, user: .guest, now: now)

        #expect(result == nil)
        #expect(repository.getCallCount == 0)
    }

    @Test
    func get_異常_条件() async {
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
    func put_異常_条件() async {
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
    func put_正常() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let location = FloatLocation.mock(id: "loc-1", districtId: district.id)
        var lastCalledFestivalId: String?
        let repository = LocationRepositoryMock(putHandler: { item, festivalId in
            lastCalledFestivalId = festivalId
            return item
        })

        let subject = make(
            locationRepository: repository,
            districtRepository: .init(getHandler: { _ in district }),
            periodRepository: .init()
        )

        let result = try await subject.put(location, user: .district(district.id))

        #expect(result == location)
        #expect(lastCalledFestivalId == district.festivalId)
        #expect(repository.putCallCount == 1)
    }

    @Test
    func delete_正常() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        var lastCalledFestivalId: String?
        var lastCalledDistrictId: String?

        let subject = make(
            locationRepository: .init(deleteHandler: { festivalId, districtId in
                lastCalledFestivalId = festivalId
                lastCalledDistrictId = districtId
            }),
            districtRepository: .init(getHandler: { _ in district }),
            periodRepository: .init()
        )

        try await subject.delete(districtId: district.id, user: .district(district.id))

        #expect(lastCalledFestivalId == district.festivalId)
        #expect(lastCalledDistrictId == district.id)
    }
}

private extension LocationUsecaseTest {
    func make(
        locationRepository: LocationRepositoryMock = .init(),
        districtRepository: DistrictRepositoryMock = .init(),
        periodRepository: PeriodRepositoryMock = .init()
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
