import Dependencies
import Shared
import Testing
@testable import Backend

struct LocationControllerTest {
    @Test
    func get_forwardsDistrictId() async throws {
        let location = FloatLocation.mock(id: "loc-1", districtId: "district-1")
        var capturedDistrictId: String?
        let mock = LocationUsecaseMock(getHandler: { districtId, _, _ in
            capturedDistrictId = districtId
            return location
        })
        let subject = make(usecase: mock)

        let request = Application.Request.make(method: .get, path: "/districts/district-1/locations", parameters: ["districtId": "district-1"])
        let response = try await subject.get(request, next: next)
        let actual = try FloatLocation?.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == location)
        #expect(capturedDistrictId == "district-1")
    }

    @Test
    func query_forwardsFestivalId() async throws {
        let expected = [FloatLocation.mock(id: "loc-1", districtId: "district-1")]
        var capturedFestivalId: String?
        let mock = LocationUsecaseMock(queryHandler: { festivalId, _, _ in
            capturedFestivalId = festivalId
            return expected
        })
        let subject = make(usecase: mock)

        let request = Application.Request.make(method: .get, path: "/festivals/festival-1/locations", parameters: ["festivalId": "festival-1"])
        let response = try await subject.query(request, next: next)
        let actual = try [FloatLocation].from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == expected)
        #expect(capturedFestivalId == "festival-1")
    }

    @Test
    func put_decodesBodyAndForwards() async throws {
        let location = FloatLocation.mock(id: "loc-1", districtId: "district-1")
        let mock = LocationUsecaseMock(putHandler: { item, _ in item })
        let subject = make(usecase: mock)

        let request = Application.Request.make(method: .put, path: "/districts/district-1/locations", body: try location.toString())
        let response = try await subject.put(request, next: next)
        let actual = try FloatLocation.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == location)
    }

    @Test
    func delete_forwardsDistrictIdAndUser() async throws {
        var capturedDistrictId: String?
        var capturedUser: UserRole?

        let mock = LocationUsecaseMock(
            deleteHandler: { districtId, user in
                capturedDistrictId = districtId
                capturedUser = user
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
        #expect(capturedDistrictId == "district-1")
        #expect(capturedUser == .district("district-1"))
        #expect(mock.deleteCallCount == 1)
    }
}

private extension LocationControllerTest {
    var next: Handler {
        { _ in throw TestError.intentional }
    }

    func make(usecase: LocationUsecaseMock) -> LocationController {
        withDependencies {
            $0[LocationUsecaseKey.self] = usecase
        } operation: {
            LocationController()
        }
    }
}
