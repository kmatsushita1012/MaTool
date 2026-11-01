import Testing
import Dependencies
import Shared
@testable import Backend

struct ApplicationTest {
    @Test
    func endpointRequiresExactPathWhileMiddlewareMatchesPrefix() async {
        let middlewareCalls = CallCounter()
        let endpointCalls = CallCounter()
        let app = Application()

        app.use(path: "/festivals/:festivalId") { request, next in
            await middlewareCalls.increment()
            return try await next(request)
        }
        app.get(path: "/festivals/:festivalId") { _, _ in
            await endpointCalls.increment()
            return try .success()
        }

        let response = await app.handle(.make(method: .get, path: "/festivals/festival-1/stores"))

        #expect(response.statusCode == 404)
        #expect(await middlewareCalls.value == 1)
        #expect(await endpointCalls.value == 0)
    }

    @Test("R01: Festival の exact path だけが endpoint に到達する")
    func r01ExactFestivalRoute() async {
        let calls = CallCounter()
        let app = Application()
        app.get(path: "/festivals/:festivalId") { _, _ in
            await calls.increment()
            return try .success()
        }

        let response = await app.handle(.make(method: .get, path: "/festivals/festival-1"))

        #expect(response.statusCode == 200)
        #expect(await calls.value == 1)
    }

    @Test("R02: Festival GET は Store 子ルートを横取りしない")
    func r02FestivalParentDoesNotCatchChild() async {
        let festivalCalls = CallCounter()
        let storeCalls = CallCounter()
        let app = Application()
        app.get(path: "/festivals/:festivalId") { _, _ in
            await festivalCalls.increment()
            return try .success()
        }
        app.get(path: "/festivals/:festivalId/stores") { _, _ in
            await storeCalls.increment()
            return try .success()
        }

        let response = await app.handle(.make(method: .get, path: "/festivals/festival-1/stores"))

        #expect(response.statusCode == 200)
        #expect(await festivalCalls.value == 0)
        #expect(await storeCalls.value == 1)
    }

    @Test("R03: 広告候補 route は Festival parent を通らず placement を受け取る")
    func r03AdvertisementRouteAndQueryParameters() async {
        let parentCalls = CallCounter()
        let adCalls = CallCounter()
        let requested = ReceivedValues()
        let app = Application()
        app.get(path: "/festivals/:festivalId") { _, _ in
            await parentCalls.increment()
            return try .success()
        }
        app.get(path: "/festivals/:festivalId/advertisements/next") { request, _ in
            await adCalls.increment()
            await requested.append("\(request.parameters["festivalId"] ?? ""):\(request.parameters["placement"] ?? "")")
            return try .success()
        }
        var request = Application.Request.make(method: .get, path: "/festivals/festival-1/advertisements/next")
        request.parameters["placement"] = "banner"

        let response = await app.handle(request)

        #expect(response.statusCode == 200)
        #expect(await parentCalls.value == 0)
        #expect(await adCalls.value == 1)
        #expect(await requested.values == ["festival-1:banner"])
    }

    @Test("R04: 既存 Festival launch route に到達する")
    func r04LegacyLaunchRoute() async {
        let calls = CallCounter()
        let app = Application()
        app.get(path: "/festivals/:festivalId/launch") { _, _ in
            await calls.increment()
            return try .success()
        }

        let response = await app.handle(.make(method: .get, path: "/festivals/festival-1/launch"))

        #expect(response.statusCode == 200)
        #expect(await calls.value == 1)
    }

    @Test("R05: 未定義の Festival 子 route は 404")
    func r05UnknownChildIsNotMatched() async {
        let calls = CallCounter()
        let app = Application()
        app.get(path: "/festivals/:festivalId") { _, _ in
            await calls.increment()
            return try .success()
        }

        let response = await app.handle(.make(method: .get, path: "/festivals/festival-1/unknown"))

        #expect(response.statusCode == 404)
        #expect(await calls.value == 0)
    }

    @Test("R06: 同一 path でも HTTP method を区別する")
    func r06GetAndPutUseDifferentHandlers() async {
        let getCalls = CallCounter()
        let putCalls = CallCounter()
        let app = Application()
        app.get(path: "/stores/:storeId") { _, _ in
            await getCalls.increment()
            return try .success()
        }
        app.put(path: "/stores/:storeId") { _, _ in
            await putCalls.increment()
            return try .success()
        }

        let getResponse = await app.handle(.make(method: .get, path: "/stores/store-1"))
        let putResponse = await app.handle(.make(method: .put, path: "/stores/store-1"))

        #expect(getResponse.statusCode == 200)
        #expect(putResponse.statusCode == 200)
        #expect(await getCalls.value == 1)
        #expect(await putCalls.value == 1)
    }

    @Test("R07: 画像 URL は POST のみを受け付ける")
    func r07ImageUploadURLUsesPostOnly() async {
        let calls = CallCounter()
        let app = Application()
        app.post(path: "/images/upload-url") { _, _ in
            await calls.increment()
            return try .success()
        }

        let getResponse = await app.handle(.make(method: .get, path: "/images/upload-url"))
        let postResponse = await app.handle(.make(method: .post, path: "/images/upload-url"))

        #expect(getResponse.statusCode == 404)
        #expect(postResponse.statusCode == 200)
        #expect(await calls.value == 1)
    }

    @Test("R08: 余分な path component は exact route に一致しない")
    func r08ExtraPathComponentDoesNotMatch() async {
        let calls = CallCounter()
        let app = Application()
        app.get(path: "/festivals/:festivalId/stores") { _, _ in
            await calls.increment()
            return try .success()
        }

        let response = await app.handle(.make(method: .get, path: "/festivals/festival-1/stores/extra"))

        #expect(response.statusCode == 404)
        #expect(await calls.value == 0)
    }

    @Test("R09: root AuthMiddleware の user を子 handler に渡す")
    func r09RootAuthMiddlewarePropagatesUser() async {
        let auth = AuthManagerMock(getAccessTokenHandler: { _ in .advertiser("owner-1") })
        let recorder = RouteUserRecorder()
        let response = await withDependencies {
            $0[AuthManagerFactoryKey.self] = { auth }
        } operation: {
            let app = Application {
                AuthMiddleware(path: "/")
                RouteRouterSpy(recorder: recorder)
            }
            return await app.handle(.make(
                method: .get,
                path: "/route",
                headers: ["authorization": "Bearer token"]
            ))
        }

        #expect(response.statusCode == 200)
        #expect(auth.getAccessTokenCallCount == 1)
        #expect(await recorder.user == .advertiser("owner-1"))
    }

    @Test("R10: Bearer がない root AuthMiddleware は guest を渡す")
    func r10RootAuthMiddlewareProvidesGuest() async {
        let recorder = RouteUserRecorder()
        let response = await withDependencies {
            $0[AuthManagerFactoryKey.self] = { AuthManagerMock() }
        } operation: {
            let app = Application {
                AuthMiddleware(path: "/")
                RouteRouterSpy(recorder: recorder)
            }
            return await app.handle(.make(method: .get, path: "/route"))
        }

        #expect(response.statusCode == 200)
        #expect(await recorder.user == .guest)
    }

    @Test("R11: parameter prefix middleware は該当 Festival のみを通す")
    func r11PrefixMiddlewareMatchesOnlyFestivalPrefix() async {
        let middlewareCalls = CallCounter()
        let app = Application()
        app.use(path: "/festivals/:festivalId") { request, next in
            await middlewareCalls.increment()
            return try await next(request)
        }
        app.get(path: "/festivalish/:festivalId") { _, _ in try .success() }

        let response = await app.handle(.make(method: .get, path: "/festivalish/festival-1"))

        #expect(response.statusCode == 200)
        #expect(await middlewareCalls.value == 0)
    }

    @Test("R12: trailing slash は既存 route と同一扱い")
    func r12TrailingSlashMatchesSameRoute() async {
        let calls = CallCounter()
        let app = Application()
        app.get(path: "/festivals/:festivalId") { _, _ in
            await calls.increment()
            return try .success()
        }

        let response = await app.handle(.make(method: .get, path: "/festivals/festival-1/"))

        #expect(response.statusCode == 200)
        #expect(await calls.value == 1)
    }

    @Test("R13: Festival parameter はリクエストごとに正しく抽出する")
    func r13FestivalParameterChangesAcrossRequests() async {
        let received = ReceivedValues()
        let app = Application()
        app.get(path: "/festivals/:festivalId/stores") { request, _ in
            await received.append(request.parameters["festivalId"] ?? "")
            return try .success()
        }

        _ = await app.handle(.make(method: .get, path: "/festivals/festival-a/stores"))
        _ = await app.handle(.make(method: .get, path: "/festivals/festival-b/stores"))

        #expect(await received.values == ["festival-a", "festival-b"])
    }

    @Test("R14: 複数 Middleware の順序と next を維持する")
    func r14MiddlewareOrderIsPreserved() async {
        let sequence = ReceivedValues()
        let app = Application()
        app.use(path: "/") { request, next in
            await sequence.append("first-before")
            let response = try await next(request)
            await sequence.append("first-after")
            return response
        }
        app.get(path: "/route", { request, next in
            await sequence.append("second-before")
            let response = try await next(request)
            await sequence.append("second-after")
            return response
        }, { request, next in
            await sequence.append("third-before")
            let response = try await next(request)
            await sequence.append("third-after")
            return response
        })
        app.get(path: "/route") { _, _ in
            await sequence.append("endpoint")
            return try .success()
        }

        let response = await app.handle(.make(method: .get, path: "/route"))

        #expect(response.statusCode == 200)
        #expect(await sequence.values == ["first-before", "second-before", "third-before", "endpoint", "third-after", "second-after", "first-after"])
    }
}

private actor CallCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

private actor ReceivedValues {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}

private actor RouteUserRecorder {
    private(set) var user: UserRole?

    func set(_ user: UserRole?) {
        self.user = user
    }
}

private struct RouteRouterSpy: Router {
    let recorder: RouteUserRecorder

    init(recorder: RouteUserRecorder) {
        self.recorder = recorder
    }

    func body(_ app: Application) {
        app.get(path: "/route") { request, _ in
            await recorder.set(request.user)
            return try .success()
        }
    }
}
