import Dependencies
import Shared
import Testing
@testable import iOSApp

struct SceneDataFetcherTests {
    @Test("祭典の起動データは祭典IDを含むlaunchエンドポイントから取得する")
    func fetchFestivalLaunchById() async throws {
        let pack = LaunchFestivalPack(
            festival: AppStateFixture.festival(), districts: [AppStateFixture.district()],
            periods: [], locations: [], checkpoints: [], hazardSections: []
        )
        let spy = try RecordingHTTPClientSpy(response: pack)

        let result = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = tokenProvidingAuthProvider()
        } operation: {
            try await SceneDataFetcher().launchFestival(festivalId: "festival")
        }

        #expect(result.festival == pack.festival)
        let request = try #require(await spy.calls().first)
        #expect(request.path == "/festivals/festival/launch")
    }

    @Test("地区の起動データは指定された地区IDを受け渡す")
    func fetchDistrictLaunch() async throws {
        let pack = LaunchDistrictPack(
            performances: [], routes: [], points: [], passages: [], currentRouteId: nil
        )
        let spy = try RecordingHTTPClientSpy(response: pack)

        let result = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = tokenProvidingAuthProvider()
        } operation: {
            try await SceneDataFetcher().launchDistrict(districtId: "district", periodId: nil)
        }

        #expect(result.routes.isEmpty)
        let request = try #require(await spy.calls().first)
        #expect(request.method == "GET")
        #expect(request.path == "/districts/district/launch")
        #expect(request.query.isEmpty)
        #expect(request.isCache == false)
    }
    @Test("地区IDから祭典起動データを取得するときは専用エンドポイントを使う")
    func fetchFestivalLaunchByDistrictId() async throws {
        let pack = LaunchFestivalPack(
            festival: AppStateFixture.festival(), districts: [],
            periods: [], locations: [], checkpoints: [], hazardSections: []
        )
        let spy = try RecordingHTTPClientSpy(response: pack)

        let result = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = tokenProvidingAuthProvider()
        } operation: {
            try await SceneDataFetcher().launchFestival(districtId: "district")
        }

        #expect(result.festival == pack.festival)
        let request = try #require(await spy.calls().first)
        #expect(request.method == "GET")
        #expect(request.path == "/districts/district/launch-festival")
        #expect(request.isCache == false)
    }

    @Test("指定した期間IDは地区起動APIのクエリに渡される")
    func fetchDistrictLaunchWithPeriod() async throws {
        let pack = LaunchDistrictPack(
            performances: [], routes: [], points: [], passages: [], currentRouteId: nil
        )
        let spy = try RecordingHTTPClientSpy(response: pack)

        _ = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = tokenProvidingAuthProvider()
        } operation: {
            try await SceneDataFetcher().launchDistrict(districtId: "district", periodId: "period")
        }

        let request = try #require(await spy.calls().first)
        #expect(request.path == "/districts/district/launch")
        #expect(request.query == ["periodId": "period"])
        #expect(request.isCache == false)
    }

    @Test("期間省略の便利メソッドは期間なしで地区起動データを取得する")
    func fetchDistrictLaunchWithoutPeriodThroughConvenience() async throws {
        let pack = LaunchDistrictPack(
            performances: [], routes: [], points: [], passages: [], currentRouteId: nil
        )
        let spy = try RecordingHTTPClientSpy(response: pack)

        _ = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = tokenProvidingAuthProvider()
        } operation: {
            try await SceneDataFetcher().launchDistrict(districtId: "district")
        }

        let request = try #require(await spy.calls().first)
        #expect(request.path == "/districts/district/launch")
        #expect(request.query.isEmpty)
    }

    @Test("祭典起動APIの通信失敗は呼び出し元に伝播する")
    func festivalLaunchFailurePropagates() async {
        let spy = RecordingHTTPClientSpy(responseJSON: "{}", shouldFail: true)

        await #expect(throws: RecordingHTTPClientSpy.Failure.requested) {
            try await withDependencies {
                $0.installTestSpies()
                $0[HTTPClientKey.self] = spy
                $0.authProvider = tokenProvidingAuthProvider()
            } operation: {
                try await SceneDataFetcher().launchFestival(festivalId: "festival")
            }
        }
        #expect(await spy.calls().map(\.path) == ["/festivals/festival/launch"])
    }

}
