import Dependencies
import Shared
import Testing
@testable import Backend

struct RouteControllerTest {
    @Test
    func get_forwardsRouteIdAndUser() async throws {
        let pack = RoutePack.mock(route: .mock(id: "route-1", districtId: "district-1"))
        var capturedId: String?
        var capturedUser: UserRole?
        let mock = RouteUsecaseMock(getHandler: { id, user in
            capturedId = id
            capturedUser = user
            return pack
        })
        let subject = make(usecase: mock)

        var request = Application.Request.make(method: .get, path: "/routes/route-1", parameters: ["routeId": "route-1"])
        request.user = .district("district-1")

        let response = try await subject.get(request, next: next)
        let actual = try RoutePack.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == pack)
        #expect(capturedId == "route-1")
        #expect(capturedUser == .district("district-1"))
    }

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

    @Test
    func query_numericYear_mapsToYearCase() async throws {
        var capturedType: RouteQueryType?
        let mock = RouteUsecaseMock(queryHandler: { _, type, _, _ in
            capturedType = type
            return []
        })
        let subject = make(usecase: mock)

        let request = Application.Request.make(
            method: .get,
            path: "/districts/district-1/routes/2026",
            parameters: ["districtId": "district-1", "year": "2026"]
        )
        _ = try await subject.query(request, next: next)

        switch capturedType {
        case .year(let year):
            #expect(year == 2026)
        default:
            #expect(Bool(false))
        }
    }

    @Test
    func post_forwardsDistrictIdAndBody() async throws {
        let pack = RoutePack.mock(route: .mock(id: "route-1", districtId: "district-1"))
        var capturedDistrictId: String?
        let mock = RouteUsecaseMock(postHandler: { districtId, item, _ in
            capturedDistrictId = districtId
            return item
        })
        let subject = make(usecase: mock)

        let request = Application.Request.make(
            method: .post,
            path: "/districts/district-1/routes",
            parameters: ["districtId": "district-1"],
            body: try pack.toString()
        )

        let response = try await subject.post(request, next: next)
        let actual = try RoutePack.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == pack)
        #expect(capturedDistrictId == "district-1")
    }

    @Test
    func put_forwardsRouteIdAndBody() async throws {
        let pack = RoutePack.mock(route: .mock(id: "route-1", districtId: "district-1"))
        var capturedId: String?
        let mock = RouteUsecaseMock(putHandler: { id, item, _ in
            capturedId = id
            return item
        })
        let subject = make(usecase: mock)

        let request = Application.Request.make(
            method: .put,
            path: "/routes/route-1",
            parameters: ["routeId": "route-1"],
            body: try pack.toString()
        )
        let response = try await subject.put(request, next: next)
        let actual = try RoutePack.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == pack)
        #expect(capturedId == "route-1")
        #expect(mock.putCallCount == 1)
    }

    @Test
    func delete_forwardsRouteId() async throws {
        var capturedId: String?
        let mock = RouteUsecaseMock(deleteHandler: { id, _ in
            capturedId = id
        })
        let subject = make(usecase: mock)

        let request = Application.Request.make(method: .delete, path: "/routes/route-1", parameters: ["routeId": "route-1"])
        let response = try await subject.delete(request, next: next)

        #expect(response.statusCode == 200)
        #expect(capturedId == "route-1")
        #expect(mock.deleteCallCount == 1)
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
