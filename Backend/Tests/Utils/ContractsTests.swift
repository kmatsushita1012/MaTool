import Testing
@testable import Backend

struct ContractsTests {
    @Test("MiddlewareComponentの既定パスは全てのリクエストに適用される")
    func defaultMiddlewarePathIsRoot() async {
        let middleware = ResponseMarkerMiddleware()
        #expect(middleware.path == "/")

        let app = Application { middleware }
        let response = await app.handle(.init(
            method: .get,
            path: "/festival/district",
            headers: [:],
            parameters: [:],
            body: nil
        ))

        #expect(response.statusCode == 418)
        #expect(response.body == "middleware:Not Found")
    }

    @Test("明示したミドルウェアパスは前方一致したリクエストにだけ適用される")
    func customMiddlewarePathIsScoped() async {
        let app = Application { ScopedResponseMarkerMiddleware(path: "/api") }
        let inside = await app.handle(.init(
            method: .post,
            path: "/api/endpoint",
            headers: [:],
            parameters: [:],
            body: nil
        ))
        let outside = await app.handle(.init(
            method: .post,
            path: "/other/endpoint",
            headers: [:],
            parameters: [:],
            body: nil
        ))

        #expect(inside.statusCode == 418)
        #expect(outside.statusCode == 404)
        #expect(outside.body == "Not Found")
    }
}

private struct ResponseMarkerMiddleware: MiddlewareComponent {
    var body: Middleware {
        { request, next in
            let original = try await next(request)
            return Response(
                statusCode: 418,
                headers: original.headers,
                body: "middleware:" + original.body
            )
        }
    }
}

private struct ScopedResponseMarkerMiddleware: MiddlewareComponent {
    let path: String
    var body: Middleware { ResponseMarkerMiddleware().body }
}
