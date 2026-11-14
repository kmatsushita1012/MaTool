import Foundation
import Dependencies
import Shared
import Testing
@testable import Backend

struct LocationUsecaseTest {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func query_正常_公開期間中は一覧を返す() async throws {
        let festivalId = "festival-1"
        let districtId = "district-1"
        let location = FloatLocation.mock(id: "loc-1", districtId: districtId, coordinate: .init(latitude: 35, longitude: 139), timestamp: now)
        let period = Period(festivalId: festivalId, date: .from(now), start: .init(hour: 0, minute: 0), end: .init(hour: 23, minute: 59))
        let repository = LocationRepositoryMock(queryHandler: { _ in [location] })

        let subject = make(
            locationRepository: repository,
            periodRepository: .init(queryByYearHandler: { _, _ in [period] })
        )

        let result = try await subject.query(by: festivalId, user: UserRole.guest, now: now)

        #expect(result == [location])
        #expect(repository.queryCallCount == 1)
    }

    @Test
    func query_正常_公開期間外は空配列を返す() async throws {
        let repository = LocationRepositoryMock(queryHandler: { _ in
            Issue.record("query should not be called when non-public")
            return []
        })
        let subject = make(
            locationRepository: repository,
            periodRepository: .init(queryByYearHandler: { _, _ in [] })
        )

        let result = try await subject.query(by: "festival-1", user: .guest, now: now)

        #expect(result.isEmpty)
        #expect(repository.queryCallCount == 0)
    }

    @Test
    func query_正常_地区権限は自地区の現在地を返す() async throws {
        let location = FloatLocation.mock(id: "loc-1", districtId: "district-1")
        let repository = LocationRepositoryMock(getHandler: { _, _ in location })
        let subject = make(
            locationRepository: repository,
            periodRepository: .init(queryByYearHandler: { _, _ in [] })
        )

        let result = try await subject.query(by: "festival-1", user: .district("district-1"), now: now)

        #expect(result == [location])
        #expect(repository.getCallCount == 1)
    }

    @Test
    func get_正常() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
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
    func get_異常_地区未登録() async {
        let subject = make(
            districtRepository: .init(getHandler: { _ in nil })
        )

        await #expect(throws: Error.notFound("指定された地区が見つかりません")) {
            _ = try await subject.get(districtId: "district-missing", user: .guest, now: now)
        }
    }

    @Test
    func put_異常_権限不一致() async {
        let location = FloatLocation.mock(id: "loc-2", districtId: "district-1", coordinate: .init(latitude: 35, longitude: 139), timestamp: now)
        let subject = make()

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
            districtRepository: .init(getHandler: { _ in district })
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
            districtRepository: .init(getHandler: { _ in district })
        )

        try await subject.delete(districtId: district.id, user: .district(district.id))

        #expect(lastCalledFestivalId == district.festivalId)
        #expect(lastCalledDistrictId == district.id)
    }

    @Test
    func query_異常_依存エラーを透過() async {
        let period = Period(
            festivalId: "festival-1",
            date: .from(now),
            start: .init(hour: 0, minute: 0),
            end: .init(hour: 23, minute: 59)
        )
        let subject = make(
            locationRepository: .init(queryHandler: { _ in throw TestError.intentional }),
            periodRepository: .init(queryByYearHandler: { _, _ in [period] })
        )

        await #expect(throws: TestError.intentional) {
            _ = try await subject.query(by: "festival-1", user: .guest, now: now)
        }
    }
    @Test("閲覧権限があっても位置情報が存在しない場合はNot Foundを返す")
    func get_異常_位置データなし() async {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let locationRepository = LocationRepositoryMock(getHandler: { _, _ in nil })
        let subject = make(
            locationRepository: locationRepository,
            districtRepository: .init(getHandler: { _ in district }),
            periodRepository: .init(queryByYearHandler: { _, _ in [] })
        )

        await #expect(throws: Error.notFound("位置情報が見つかりません")) {
            _ = try await subject.get(
                districtId: district.id,
                user: .district(district.id),
                now: now
            )
        }
        #expect(locationRepository.getCallCount == 1)
    }

    @Test("他地区の位置情報を削除しようとした場合は拒否し書き込まない")
    func delete_異常_権限不一致() async {
        let locationRepository = LocationRepositoryMock()
        let districtRepository = DistrictRepositoryMock()
        let subject = make(
            locationRepository: locationRepository,
            districtRepository: districtRepository
        )

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            try await subject.delete(
                districtId: "district-1",
                user: .district("another")
            )
        }
        #expect(locationRepository.deleteCallCount == 0)
        #expect(districtRepository.getCallCount == 0)
    }

    @Test("地区情報が削除済みなら位置削除を許可しない")
    func delete_異常_地区未登録() async {
        let locationRepository = LocationRepositoryMock()
        let subject = make(
            locationRepository: locationRepository,
            districtRepository: .init(getHandler: { _ in nil })
        )

        await #expect(throws: Error.notFound("地区が見つかりません")) {
            try await subject.delete(
                districtId: "district-1",
                user: .district("district-1")
            )
        }
        #expect(locationRepository.deleteCallCount == 0)
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
