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
        #expect(requests.first?.path == "/v2/festivals/festival/periods")
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
        #expect(await spy.calls().map(\.path) == ["/v2/periods/period"])
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
        #expect(await spy.calls().map(\.path) == ["/v2/festivals/festival/periods"])
    }
}
