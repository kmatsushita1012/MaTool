import Dependencies
import Shared
import Testing
@testable import Backend

struct LocationControllerTest {
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
