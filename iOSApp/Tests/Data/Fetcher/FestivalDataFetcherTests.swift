import Dependencies
import Shared
import Testing
@testable import iOSApp

struct FestivalDataFetcherTests {
    @Test("祭典一覧のGETは認証無しで正しいパスへアクセスする")
    func getFestivals() async throws {
        let festival = AppStateFixture.festival()
        let spy = try RecordingHTTPClientSpy(response: [festival])

        let response = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
        } operation: {
            try await FestivalDataFetcher().fetchAll()
        }

        #expect(response == [festival])
        let requests = await spy.calls()
        #expect(requests.map(\.path) == ["/festivals"])
        #expect(requests.map(\.method) == ["GET"])
    }

    @Test("祭典詳細のGETは祭典IDを指定する")
    func getFestivalPack() async throws {
        let pack = FestivalPack(
            festival: AppStateFixture.festival(),
            checkpoints: [], hazardSections: []
        )
        let spy = try RecordingHTTPClientSpy(response: pack)

        let response = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
        } operation: {
            try await FestivalDataFetcher().fetch(festivalID: "festival")
        }

        #expect(response.festival == pack.festival)
        #expect(await spy.calls().map(\.path) == ["/festivals/festival"])
    }

    @Test("祭典更新はPUTで同じ祭典IDと認証情報を付けて送信する")
    func updateFestival() async throws {
        let pack = FestivalPack(
            festival: AppStateFixture.festival(),
            checkpoints: [], hazardSections: []
        )
        let spy = try RecordingHTTPClientSpy(response: pack)
        var auth = AuthProviderSpy().client
        auth.getTokens = { "access-token" }

        let response = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = auth
        } operation: {
            try await FestivalDataFetcher().update(
                festival: pack.festival,
                checkPoints: pack.checkpoints,
                hazardSections: pack.hazardSections
            )
        }

        #expect(response == pack)
        let request = try #require(await spy.calls().first)
        #expect(request.path == "/festivals/festival")
        #expect(request.method == "PUT")
        #expect(request.accessToken == "access-token")
        #expect(request.body != nil)
    }

    @Test("Backend障害はリクエストごとにエラーとして伝播する")
    func propagatesHTTPFailure() async {
        let spy = RecordingHTTPClientSpy(responseJSON: "[]", shouldFail: true)
        await #expect(throws: RecordingHTTPClientSpy.Failure.requested) {
            try await withDependencies {
                $0.installTestSpies()
                $0[HTTPClientKey.self] = spy
            } operation: {
                try await FestivalDataFetcher().fetchAll()
            }
        }
    }
}
