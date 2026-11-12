import Dependencies
import Shared
import Testing
@testable import iOSApp

struct RouteDataFetcherTests {
    @Test("経路一覧は地区IDと年度クエリを指定する")
    func fetchRoutesByYear() async throws {
        let route = AppStateFixture.route()
        let spy = try RecordingHTTPClientSpy(response: [route])
        var auth = AuthProviderSpy().client
        auth.getTokens = { "token" }

        let result = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = tokenProvidingAuthProvider()
            $0.authProvider = auth
        } operation: {
            try await RouteDataFetcher().fetchAll(districtID: "district", query: .year(2026))
        }

        #expect(result == [route])
        let request = try #require(await spy.calls().first)
        #expect(request.path == "/districts/district/routes")
        #expect(request.query == ["year": "2026"])
        #expect(request.accessToken == "token")
    }

    @Test("経路詳細取得は一致するIDを使用する")
    func fetchRoutePack() async throws {
        let route = AppStateFixture.route()
        let pack = RoutePack(route: route, points: [], passages: [])
        let spy = try RecordingHTTPClientSpy(response: pack)

        let result = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = tokenProvidingAuthProvider()
        } operation: {
            try await RouteDataFetcher().fetch(routeID: route.id)
        }

        #expect(result.route == route)
        #expect(await spy.calls().map(\.path) == ["/routes/route"])
    }

    @Test("経路の作成・編集・削除は正しいURLと本文を送信する")
    func mutationsUseCorrectPaths() async throws {
        let route = AppStateFixture.route()
        let pack = RoutePack(route: route, points: [], passages: [])
        let spy = try RecordingHTTPClientSpy(response: pack)
        var auth = AuthProviderSpy().client
        auth.getTokens = { "token" }

        try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = tokenProvidingAuthProvider()
            $0.authProvider = auth
        } operation: {
            let fetcher = RouteDataFetcher()
            let created = try await fetcher.create(
                districtID: "district", route: route, points: [], passages: []
            )
            #expect(created.route == route)
            let updated = try await fetcher.update(route, points: [], passages: [])
            #expect(updated.route == route)
            try await fetcher.delete(route.id)
        }

        let calls = await spy.calls()
        #expect(calls.map(\.method) == ["POST", "PUT", "DELETE"])
        #expect(calls.map(\.path) == [
            "/districts/district/routes", "/routes/route", "/routes/route"
        ])
        #expect(calls.allSatisfy { $0.accessToken == "token" })
        #expect(calls[0].body != nil)
        #expect(calls[1].body != nil)
        #expect(calls[2].body == nil)
    }

    @Test("HTTPの失敗時は成功値を生成しない")
    func failurePropagates() async {
        let spy = RecordingHTTPClientSpy(responseJSON: "{}", shouldFail: true)
        await #expect(throws: RecordingHTTPClientSpy.Failure.requested) {
            try await withDependencies {
                $0.installTestSpies()
                $0[HTTPClientKey.self] = spy
                $0.authProvider = tokenProvidingAuthProvider()
            } operation: {
                try await RouteDataFetcher().fetch(routeID: "route")
            }
        }
    }
}
