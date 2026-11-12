import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

struct LocationDataFetcherTests {
    @Test("現在地一覧は祭典スコープで非キャッシュのGETを行う")
    func fetchLocationsDisablesCaching() async throws {
        let location = FloatLocation(
            id: "loc", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139),
            timestamp: Date(timeIntervalSince1970: 100)
        )
        let spy = try RecordingHTTPClientSpy(response: [location])
        let result = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = tokenProvidingAuthProvider()
        } operation: {
            try await LocationDataFetcher().fetchAll(festivalId: "festival")
        }

        #expect(result == [location])
        let request = try #require(await spy.calls().first)
        #expect(request.path == "/festivals/festival/locations")
        #expect(request.method == "GET")
        #expect(request.isCache == false)
    }

    @Test("地区の位置情報を取得し、存在しない場合のnilも保持する")
    func fetchLocation() async throws {
        let spy = RecordingHTTPClientSpy(responseJSON: "null")

        let result: FloatLocation? = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = tokenProvidingAuthProvider()
        } operation: {
            try await LocationDataFetcher().fetch(districtId: "district")
        }

        #expect(result == nil)
        let request = try #require(await spy.calls().first)
        #expect(request.path == "/districts/district/locations")
        #expect(request.isCache == false)
    }

    @Test("位置更新はPUT本文・トークンを使用し、削除はDELETEを使用する")
    func updateAndDelete() async throws {
        let location = FloatLocation(
            id: "loc", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139),
            timestamp: Date(timeIntervalSince1970: 100)
        )
        let spy = try RecordingHTTPClientSpy(response: location)
        var auth = AuthProviderSpy().client
        auth.getTokens = { "token" }
        try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = tokenProvidingAuthProvider()
            $0.authProvider = auth
        } operation: {
            let fetcher = LocationDataFetcher()
            #expect(try await fetcher.update(location) == location)
            try await fetcher.delete(districtId: "district")
        }

        let calls = await spy.calls()
        #expect(calls.map(\.method) == ["PUT", "DELETE"])
        #expect(calls.map(\.path) == [
            "/districts/district/locations", "/districts/district/locations"
        ])
        #expect(calls.allSatisfy { $0.accessToken == "token" })
        #expect(calls[0].body != nil)
    }

    @Test("通信失敗時はエラーをそのまま伝播する")
    func failurePropagates() async {
        let spy = RecordingHTTPClientSpy(responseJSON: "[]", shouldFail: true)
        await #expect(throws: RecordingHTTPClientSpy.Failure.requested) {
            try await withDependencies {
                $0.installTestSpies()
                $0[HTTPClientKey.self] = spy
            } operation: {
                try await LocationDataFetcher().fetchAll(festivalId: "festival")
            }
        }
    }
}
