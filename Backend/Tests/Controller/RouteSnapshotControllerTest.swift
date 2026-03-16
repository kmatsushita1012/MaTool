import Testing
@testable import Backend

struct RouteSnapshotControllerTest {
    @Test
    func get_正常_固定PNGを返す() async throws {
        let subject = RouteSnapshotController()
        let request = Application.Request.make(
            method: .get,
            path: "/routes/route-1/snapshot",
            parameters: ["routeId": "route-1"]
        )

        let response = try await subject.get(request, next: next)

        #expect(response.statusCode == 200)
        #expect(response.headers["Content-Type"] == "image/png")
        #expect(response.isBase64Encoded == true)
        #expect(response.body.isEmpty == false)
    }

    @Test
    func get_異常_routeId未指定でbadRequest() async {
        let subject = RouteSnapshotController()
        let request = Application.Request.make(method: .get, path: "/routes//snapshot")

        await #expect(throws: Application.Error.badRequest("送信されたデータが不十分です。")) {
            _ = try await subject.get(request, next: next)
        }
    }
}

private extension RouteSnapshotControllerTest {
    var next: Handler {
        { _ in throw TestError.intentional }
    }
}
