import Dependencies
import Shared
import Testing
@testable import Backend

struct DistrictControllerTest {
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
