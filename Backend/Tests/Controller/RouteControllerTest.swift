import Dependencies
import Shared
import Testing
@testable import Backend

struct RouteControllerTest {
    @Test
    func query_supportsLatestYearShortcut() async throws {
        let routes = [Route.mock(id: "route-1", districtId: "district-1")]
        var capturedDistrictId: String?
        var capturedUser: UserRole?
        var capturedType: RouteQueryType?

        let mock = RouteUsecaseMock(
            queryHandler: { districtId, type, _, user in
                capturedDistrictId = districtId
                capturedType = type
                capturedUser = user
                return routes
            }
        )
        let subject = make(usecase: mock)

        var request = Application.Request.make(
            method: .get,
            path: "/districts/district-1/routes/latest",
            parameters: ["districtId": "district-1", "year": "latest"]
        )
        request.user = .district("district-1")

        let response = try await subject.query(request, next: next)
        let actual = try [Route].from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == routes)
        #expect(capturedDistrictId == "district-1")
        #expect(capturedUser == .district("district-1"))
        switch capturedType {
        case .latest:
            #expect(Bool(true))
        default:
            #expect(Bool(false))
        }
        #expect(mock.queryCallCount == 1)
    }
}

private extension RouteControllerTest {
    var next: Handler {
        { _ in throw TestError.intentional }
    }

    func make(usecase: RouteUsecaseMock) -> RouteController {
        withDependencies {
            $0[RouteUsecaseKey.self] = usecase
        } operation: {
            RouteController()
        }
    }
}
