import Dependencies
import Shared
import Testing
@testable import Backend

struct RouteControllerTest {
    @Test
    func get_正常() async throws {
        let pack = RoutePack.mock(route: .mock(id: "route-1", districtId: "district-1"))
        var lastCalledId: String?
        var lastCalledUser: UserRole?
        let mock = RouteUsecaseMock(getHandler: { id, user in
            lastCalledId = id
            lastCalledUser = user
            return pack
        })
        let subject = make(usecase: mock)

        var request = Application.Request.make(method: .get, path: "/routes/route-1", parameters: ["routeId": "route-1"])
        request.user = .district("district-1")

        let response = try await subject.get(request, next: next)
        let actual = try RoutePack.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == pack)
        #expect(lastCalledId == "route-1")
        #expect(lastCalledUser == .district("district-1"))
    }

    @Test
    func query_正常_latest指定() async throws {
        let routes = [Route.mock(id: "route-1", districtId: "district-1")]
        var lastCalledDistrictId: String?
        var lastCalledUser: UserRole?
        var lastCalledType: RouteQueryType?

        let mock = RouteUsecaseMock(
            queryHandler: { districtId, type, _, user in
                lastCalledDistrictId = districtId
                lastCalledType = type
                lastCalledUser = user
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
        #expect(lastCalledDistrictId == "district-1")
        #expect(lastCalledUser == .district("district-1"))
        switch lastCalledType {
        case .latest:
            #expect(Bool(true))
        default:
            #expect(Bool(false))
        }
        #expect(mock.queryCallCount == 1)
    }

    @Test
    func query_正常_年指定() async throws {
        var lastCalledType: RouteQueryType?
        let mock = RouteUsecaseMock(queryHandler: { _, type, _, _ in
            lastCalledType = type
            return []
        })
        let subject = make(usecase: mock)

        let request = Application.Request.make(
            method: .get,
            path: "/districts/district-1/routes/2026",
            parameters: ["districtId": "district-1", "year": "2026"]
        )
        _ = try await subject.query(request, next: next)

        switch lastCalledType {
        case .year(let year):
            #expect(year == 2026)
        default:
            #expect(Bool(false))
        }
    }

    @Test
    func post_正常() async throws {
        let pack = RoutePack.mock(route: .mock(id: "route-1", districtId: "district-1"))
        var lastCalledDistrictId: String?
        let mock = RouteUsecaseMock(postHandler: { districtId, item, _ in
            lastCalledDistrictId = districtId
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
        #expect(lastCalledDistrictId == "district-1")
    }

    @Test
    func put_正常() async throws {
        let pack = RoutePack.mock(route: .mock(id: "route-1", districtId: "district-1"))
        var lastCalledId: String?
        let mock = RouteUsecaseMock(putHandler: { id, item, _ in
            lastCalledId = id
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
        #expect(lastCalledId == "route-1")
        #expect(mock.putCallCount == 1)
    }

    @Test
    func delete_正常() async throws {
        var lastCalledId: String?
        let mock = RouteUsecaseMock(deleteHandler: { id, _ in
            lastCalledId = id
        })
        let subject = make(usecase: mock)

        let request = Application.Request.make(method: .delete, path: "/routes/route-1", parameters: ["routeId": "route-1"])
        let response = try await subject.delete(request, next: next)

        #expect(response.statusCode == 200)
        #expect(lastCalledId == "route-1")
        #expect(mock.deleteCallCount == 1)
    }

    @Test
    func get_異常_ユースケースエラー透過() async {
        let mock = RouteUsecaseMock(getHandler: { _, _ in throw TestError.intentional })
        let subject = make(usecase: mock)
        let request = Application.Request.make(method: .get, path: "/routes/route-1", parameters: ["routeId": "route-1"])

        await #expect(throws: TestError.intentional) {
            _ = try await subject.get(request, next: next)
        }
    }
}

private extension RouteControllerTest {
    var next: Handler {
        { _ in throw TestError.intentional }
    }

    func make(usecase: RouteUsecaseMock = .init()) -> RouteController {
        withDependencies {
            $0[RouteUsecaseKey.self] = usecase
        } operation: {
            RouteController()
        }
    }
}
