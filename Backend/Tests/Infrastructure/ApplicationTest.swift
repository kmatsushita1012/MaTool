import Testing
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
}

private actor CallCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
