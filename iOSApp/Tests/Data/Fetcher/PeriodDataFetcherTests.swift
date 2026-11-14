import Dependencies
import Shared
import Testing
@testable import iOSApp

struct PeriodDataFetcherTests {
    @Test("期間一覧取得は祭典IDと対象年をGETに渡す")
    func fetchAllSendsFestivalAndYear() async throws {
        let period = AppStateFixture.period()
        let spy = try RecordingHTTPClientSpy(response: [period])
        let response = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
        } operation: {
            try await PeriodDataFetcher().fetchAll(festivalID: "festival", query: .year(2026))
        }

        #expect(response == [period])
        let requests = await spy.calls()
        #expect(requests.count == 1)
        #expect(requests.first?.method == "GET")
        #expect(requests.first?.path == "/festivals/festival/periods")
        #expect(requests.first?.query == ["year": "2026"])
        #expect(requests.first?.accessToken == nil)
    }

    @Test("期間個別取得は指定IDに対応するエンドポイントを使用する")
    func fetchById() async throws {
        let period = AppStateFixture.period()
        let spy = try RecordingHTTPClientSpy(response: period)
        let response = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
        } operation: {
            try await PeriodDataFetcher().fetch(period.id)
        }

        #expect(response == period)
        #expect(await spy.calls().map(\.path) == ["/periods/period"])
    }

    @Test("期間作成・更新・削除はアクセストークン付きで正しいHTTPメソッドを使用する")
    func mutationsUseAuthenticatedRequests() async throws {
        let period = AppStateFixture.period()
        let spy = try RecordingHTTPClientSpy(response: period)
        var auth = AuthProviderSpy().client
        auth.getTokens = { "token-123" }
        try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = auth
        } operation: {
            let fetcher = PeriodDataFetcher()
            #expect(try await fetcher.create(period) == period)
            #expect(try await fetcher.update(period) == period)
            try await fetcher.delete(period.id)
        }

        let requests = await spy.calls()
        #expect(requests.map(\.method) == ["POST", "PUT", "DELETE"])
        #expect(requests.map(\.path) == [
            "/festivals/festival/periods", "/periods/period", "/periods/period"
        ])
        #expect(requests.allSatisfy { $0.accessToken == "token-123" })
        #expect(requests[0].body != nil)
        #expect(requests[1].body != nil)
        #expect(requests[2].body == nil)
    }

    @Test("依存するHTTP通信の失敗を握りつぶさず伝播する")
    func networkFailurePropagates() async throws {
        let spy = RecordingHTTPClientSpy(responseJSON: "[]", shouldFail: true)

        await #expect(throws: RecordingHTTPClientSpy.Failure.requested) {
            try await withDependencies {
                $0.installTestSpies()
                $0[HTTPClientKey.self] = spy
            } operation: {
                try await PeriodDataFetcher().fetchAll(festivalID: "festival", query: .all)
            }
        }
        #expect(await spy.calls().map(\.path) == ["/festivals/festival/periods"])
    }
}
