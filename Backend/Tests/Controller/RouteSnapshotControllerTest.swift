import Dependencies
import Shared
import Testing
@testable import Backend

struct RouteSnapshotControllerTest {
    @Test
    func get_正常_固定PNGを返す() async throws {
        let subject = withDependencies {
            $0[RouteSnapshotUsecaseKey.self] = RouteSnapshotUsecaseMock(
                getHandler: { _ in
                    .init(contentType: "image/png", base64Body: "ZmFrZQ==")
                }
            )
        } operation: {
            RouteSnapshotController()
        }
        let request = Application.Request.make(
            method: .get,
            path: "/routes/route-1/snapshot",
            parameters: ["routeId": "route-1"]
        )

        let response = try await subject.get(request, next: next)

        #expect(response.statusCode == 200)
        #expect(response.headers["Content-Type"] == "image/png")
        #expect(response.isBase64Encoded == true)
        #expect(response.body == "ZmFrZQ==")
    }

    @Test
    func get_異常_routeId未指定でbadRequest() async {
        let subject = RouteSnapshotController()
        let request = Application.Request.make(method: .get, path: "/routes//snapshot")

        await #expect(throws: Application.Error.badRequest("送信されたデータが不十分です。")) {
            _ = try await subject.get(request, next: next)
        }
    }

    @Test
    func post_正常_RoutePackで固定PNGを返す() async throws {
        let pack = RoutePack.mock(route: .mock(id: "route-1", districtId: "district-1"))
        let subject = withDependencies {
            $0[RouteSnapshotUsecaseKey.self] = RouteSnapshotUsecaseMock(
                postHandler: { received in
                    #expect(received.route.id == "route-1")
                    return .init(contentType: "image/png", base64Body: "cG9zdA==")
                }
            )
        } operation: {
            RouteSnapshotController()
        }
        let request = Application.Request.make(
            method: .post,
            path: "/routes/snapshot",
            body: try pack.toString()
        )

        let response = try await subject.post(request, next: next)

        #expect(response.statusCode == 200)
        #expect(response.headers["Content-Type"] == "image/png")
        #expect(response.isBase64Encoded == true)
        #expect(response.body == "cG9zdA==")
    }
}

private extension RouteSnapshotControllerTest {
    var next: Handler {
        { _ in throw TestError.intentional }
    }
}
