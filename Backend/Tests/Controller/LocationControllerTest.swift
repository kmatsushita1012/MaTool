import Foundation
import Dependencies
import Shared
import Testing
@testable import Backend

struct LocationControllerTest {
    @Test
    func get_正常() async throws {
        let location = FloatLocation.mock(id: "loc-1", districtId: "district-1")
        var lastCalledDistrictId: String?
        let mock = LocationUsecaseMock(getHandler: { districtId, _, _ in
            lastCalledDistrictId = districtId
            return location
        })
        let subject = make(usecase: mock)

        let request = Application.Request.make(method: .get, path: "/districts/district-1/locations", parameters: ["districtId": "district-1"])
        let response = try await subject.get(request, next: next)
        let actual = try FloatLocation?.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == location)
        #expect(lastCalledDistrictId == "district-1")
    }

    @Test
    func query_正常() async throws {
        let expected = [FloatLocation.mock(id: "loc-1", districtId: "district-1")]
        var lastCalledFestivalId: String?
        let mock = LocationUsecaseMock(queryHandler: { festivalId, _, _ in
            lastCalledFestivalId = festivalId
            return expected
        })
        let subject = make(usecase: mock)

        let request = Application.Request.make(method: .get, path: "/festivals/festival-1/locations", parameters: ["festivalId": "festival-1"])
        let response = try await subject.query(request, next: next)
        let actual = try [FloatLocation].from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == expected)
        #expect(lastCalledFestivalId == "festival-1")
    }

    @Test
    func query_日付をまたぐ公開期間は開始日から終了翌日まで一覧を返す() async throws {
        let period = Period(
            festivalId: "festival-1",
            date: .init(year: 2026, month: 10, day: 2),
            start: .init(hour: 22, minute: 0),
            end: .init(hour: 2, minute: 0)
        )
        let location = FloatLocation.mock(id: "loc-1", districtId: "district-1")

        let beforeStart = await queryLocationEndpoint(
            at: Date.combine(date: .init(year: 2026, month: 10, day: 2), time: .init(hour: 21, minute: 29)),
            period: period,
            location: location
        )
        let startBuffer = await queryLocationEndpoint(
            at: Date.combine(date: .init(year: 2026, month: 10, day: 2), time: .init(hour: 21, minute: 30)),
            period: period,
            location: location
        )
        let beforeMidnight = await queryLocationEndpoint(
            at: Date.combine(date: .init(year: 2026, month: 10, day: 2), time: .init(hour: 23, minute: 30)),
            period: period,
            location: location
        )
        let afterMidnight = await queryLocationEndpoint(
            at: Date.combine(date: .init(year: 2026, month: 10, day: 3), time: .init(hour: 1, minute: 30)),
            period: period,
            location: location
        )
        let afterEnd = await queryLocationEndpoint(
            at: Date.combine(date: .init(year: 2026, month: 10, day: 3), time: .init(hour: 2, minute: 1)),
            period: period,
            location: location
        )

        #expect(try [FloatLocation].from(beforeStart.body).isEmpty)
        #expect(try [FloatLocation].from(startBuffer.body) == [location])
        #expect(try [FloatLocation].from(beforeMidnight.body) == [location])
        #expect(try [FloatLocation].from(afterMidnight.body) == [location])
        #expect(try [FloatLocation].from(afterEnd.body).isEmpty)
        #expect(beforeStart.statusCode == 200)
        #expect(startBuffer.statusCode == 200)
        #expect(beforeMidnight.statusCode == 200)
        #expect(afterMidnight.statusCode == 200)
        #expect(afterEnd.statusCode == 200)

        let previousYearPeriod = Period(
            festivalId: "festival-1",
            date: .init(year: 2025, month: 12, day: 31),
            start: .init(hour: 22, minute: 0),
            end: .init(hour: 2, minute: 0)
        )
        let newYearAfterMidnight = await queryLocationEndpoint(
            at: Date.combine(date: .init(year: 2026, month: 1, day: 1), time: .init(hour: 1, minute: 30)),
            period: previousYearPeriod,
            location: location
        )
        #expect(try [FloatLocation].from(newYearAfterMidnight.body) == [location])
        #expect(newYearAfterMidnight.statusCode == 200)
    }

    @Test
    func put_正常() async throws {
        let location = FloatLocation.mock(id: "loc-1", districtId: "district-1")
        let mock = LocationUsecaseMock(putHandler: { item, _ in item })
        let subject = make(usecase: mock)

        let request = Application.Request.make(method: .put, path: "/districts/district-1/locations", body: try location.toString())
        let response = try await subject.put(request, next: next)
        let actual = try FloatLocation.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == location)
        #expect(mock.putCallCount == 1)
    }

    @Test
    func put_DateをUnix秒で受け取り応答する() async throws {
        let expected = Date(timeIntervalSince1970: 1_700_000_000)
        var receivedTimestamp: Date?
        let mock = LocationUsecaseMock(putHandler: { location, _ in
            receivedTimestamp = location.timestamp
            return location
        })
        let subject = make(usecase: mock)
        let app = Application()
        app.put(path: "/districts/:districtId/locations", subject.put)
        let request = Application.Request.make(
            method: .put,
            path: "/districts/district-1/locations",
            body: """
            {"id":"loc-1","districtId":"district-1","coordinate":{"latitude":35,"longitude":139},"timestamp":1700000000}
            """
        )

        let response = await app.handle(request)
        let body = try #require(JSONSerialization.jsonObject(with: Data(response.body.utf8)) as? [String: Any])

        #expect(response.statusCode == 200)
        #expect(receivedTimestamp == expected)
        #expect(body["timestamp"] as? Double == expected.timeIntervalSince1970)
    }

    @Test
    func delete_正常() async throws {
        var lastCalledDistrictId: String?
        var lastCalledUser: UserRole?

        let mock = LocationUsecaseMock(
            deleteHandler: { districtId, user in
                lastCalledDistrictId = districtId
                lastCalledUser = user
            }
        )
        let subject = make(usecase: mock)

        var request = Application.Request.make(
            method: .delete,
            path: "/districts/district-1/locations",
            parameters: ["districtId": "district-1"]
        )
        request.user = .district("district-1")

        let response = try await subject.delete(request, next: next)

        #expect(response.statusCode == 200)
        #expect(response.body == "{}")
        #expect(lastCalledDistrictId == "district-1")
        #expect(lastCalledUser == .district("district-1"))
        #expect(mock.deleteCallCount == 1)
    }

    @Test
    func query_異常_ユースケースエラー透過() async {
        let mock = LocationUsecaseMock(queryHandler: { _, _, _ in throw TestError.intentional })
        let subject = make(usecase: mock)
        let request = Application.Request.make(
            method: .get,
            path: "/festivals/festival-1/locations",
            parameters: ["festivalId": "festival-1"]
        )

        await #expect(throws: TestError.intentional) {
            _ = try await subject.query(request, next: next)
        }
    }
}

private extension LocationControllerTest {
    var next: Handler {
        { _ in throw TestError.intentional }
    }

    func make(usecase: LocationUsecaseMock = .init()) -> LocationController {
        withDependencies {
            $0[LocationUsecaseKey.self] = usecase
        } operation: {
            LocationController()
        }
    }

    func queryLocationEndpoint(at now: Date, period: Period, location: FloatLocation) async -> Application.Response {
        await withDependencies {
            $0[LocationRepositoryKey.self] = LocationRepositoryMock(queryHandler: { _ in [location] })
            $0[PeriodRepositoryKey.self] = PeriodRepositoryMock(queryByYearHandler: { _, year in
                year == period.date.year ? [period] : []
            })
            $0[LocationUsecaseKey.self] = LocationUsecase()
        } operation: {
            let app = Application()
            let controller = LocationController(now: { now })
            app.get(path: "/festivals/:festivalId/locations", controller.query)
            let request = Application.Request.make(
                method: .get,
                path: "/festivals/festival-1/locations"
            )
            return await app.handle(request)
        }
    }
}
