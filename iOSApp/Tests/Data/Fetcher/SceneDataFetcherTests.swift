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
}
