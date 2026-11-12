import Dependencies
import Testing
@testable import iOSApp

struct DataFetcherTests {
    @Test("全件取得はクエリパラメータを付与しない")
    func allDoesNotAddQuery() {
        #expect(Query.all.queryItems.isEmpty)
    }

    @Test("年度指定は数値として送信する")
    func yearUsesNumericQueryValue() {
        let query = Query.year(2026).queryItems

        #expect(query.count == 1)
        #expect(query["year"] as? Int == 2026)
    }

    @Test("最新年度指定はlatest文字列として送信する")
    func latestUsesLiteralQueryValue() {
        let query = Query.latest.queryItems

        #expect(query.count == 1)
        #expect(query["year"] as? String == "latest")
    }

    @Test("認証トークンの取得に成功するとその値を返す")
    func tokenSuccess() async {
        var auth = AuthProviderSpy().client
        auth.getTokens = { "access-token" }
        let fetcher = withDependencies {
            $0.authProvider = auth
        } operation: {
            PeriodDataFetcher()
        }

        #expect(await fetcher.getToken() == "access-token")
    }

    @Test("認証トークンの取得に失敗するとnilを返す")
    func tokenFailureDoesNotThrow() async {
        var auth = AuthProviderSpy().client
        auth.getTokens = { throw SpyInvocationError.unexpected("expired token") }
        let fetcher = withDependencies {
            $0.authProvider = auth
        } operation: {
            PeriodDataFetcher()
        }

        #expect(await fetcher.getToken() == nil)
    }
}
