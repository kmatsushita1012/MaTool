import Dependencies
import Shared
import Testing
@testable import Backend

struct DistrictControllerTest {
    @Test
    func get_forwardsDistrictId() async throws {
        let expected = DistrictPack.mock(district: .mock(id: "district-1", festivalId: "festival-1"))
        var capturedId: String?
        let mock = DistrictUsecaseMock(getHandler: { id in
            capturedId = id
            return expected
        })
        let subject = make(usecase: mock)

        let request = Application.Request.make(method: .get, path: "/districts/district-1", parameters: ["districtId": "district-1"])
        let response = try await subject.get(request, next: next)
        let actual = try DistrictPack.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == expected)
        #expect(capturedId == "district-1")
    }

    @Test
    func query_forwardsFestivalId() async throws {
        let expected = [District.mock(id: "district-1", festivalId: "festival-1")]
        var capturedFestivalId: String?
        let mock = DistrictUsecaseMock(queryHandler: { festivalId in
            capturedFestivalId = festivalId
            return expected
        })
        let subject = make(usecase: mock)

        let request = Application.Request.make(method: .get, path: "/festivals/festival-1/districts", parameters: ["festivalId": "festival-1"])
        let response = try await subject.query(request, next: next)
        let actual = try [District].from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == expected)
        #expect(capturedFestivalId == "festival-1")
    }

    @Test
    func post_decodesFormAndForwardsParameters() async throws {
        let expected = DistrictPack.mock(district: .mock(id: "district-1", festivalId: "festival-1"))
        var capturedHeadquarterId: String?
        var capturedName: String?
        var capturedEmail: String?
        var capturedUser: UserRole?

        let mock = DistrictUsecaseMock(
            postHandler: { user, headquarterId, newDistrictName, email in
                capturedUser = user
                capturedHeadquarterId = headquarterId
                capturedName = newDistrictName
                capturedEmail = email
                return expected
            }
        )
        let subject = make(usecase: mock)

        let body = DistrictCreateForm(name: "new-district", email: "district@example.com")
        let request = Application.Request.make(
            method: .post,
            path: "/festivals/festival-1/districts",
            parameters: ["festivalId": "festival-1"],
            body: try body.toString()
        )

        let response = try await subject.post(request, next: next)
        let actual = try DistrictPack.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == expected)
        #expect(capturedUser == .guest)
        #expect(capturedHeadquarterId == "festival-1")
        #expect(capturedName == "new-district")
        #expect(capturedEmail == "district@example.com")
        #expect(mock.postCallCount == 1)
    }

    @Test
    func put_forwardsDistrictPackAndUser() async throws {
        let pack = DistrictPack.mock(district: .mock(id: "district-1", festivalId: "festival-1"))
        var capturedId: String?
        var capturedUser: UserRole?
        let mock = DistrictUsecaseMock(putPackHandler: { id, item, user in
            capturedId = id
            capturedUser = user
            return item
        })
        let subject = make(usecase: mock)

        var request = Application.Request.make(
            method: .put,
            path: "/districts/district-1",
            parameters: ["districtId": "district-1"],
            body: try pack.toString()
        )
        request.user = .district("district-1")

        let response = try await subject.put(request, next: next)
        let actual = try DistrictPack.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == pack)
        #expect(capturedId == "district-1")
        #expect(capturedUser == .district("district-1"))
    }

    @Test
    func updateDistrict_forwardsDistrictBody() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        var capturedId: String?
        var capturedDistrict: District?
        let mock = DistrictUsecaseMock(putDistrictHandler: { id, item, _ in
            capturedId = id
            capturedDistrict = item
            return item
        })
        let subject = make(usecase: mock)

        let request = Application.Request.make(
            method: .put,
            path: "/districts/district-1/core",
            parameters: ["districtId": "district-1"],
            body: try district.toString()
        )

        let response = try await subject.updateDistrict(request, next: next)
        let actual = try District.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == district)
        #expect(capturedId == "district-1")
        #expect(capturedDistrict == district)
    }
}

private extension DistrictControllerTest {
    var next: Handler {
        { _ in throw TestError.intentional }
    }

    func make(usecase: DistrictUsecaseMock) -> DistrictController {
        withDependencies {
            $0[DistrictUsecaseKey.self] = usecase
        } operation: {
            DistrictController()
        }
    }
}
