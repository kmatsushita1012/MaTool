import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

struct DistrictDataFetcherTests {
    @Test("地区一覧は祭典IDに対応するGETで取得する")
    func fetchAllUsesFestivalScope() async throws {
        let district = AppStateFixture.district()
        let spy = try RecordingHTTPClientSpy(response: [district])
        let result = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
        } operation: {
            try await DistrictDataFetcher().fetchAll(festivalID: "festival")
        }

        #expect(result == [district])
        #expect(await spy.calls().map(\.path) == ["/festivals/festival/districts"])
        #expect(await spy.calls().map(\.method) == ["GET"])
    }

    @Test("地区の個別取得は地区IDのGETを使用する")
    func fetchDistrict() async throws {
        let pack = DistrictPack(district: AppStateFixture.district(), performances: [])
        let spy = try RecordingHTTPClientSpy(response: pack)
        let result = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
        } operation: {
            try await DistrictDataFetcher().fetch(districtID: "district")
        }

        #expect(result == pack)
        #expect(await spy.calls().map(\.path) == ["/districts/district"])
    }

    @Test("地区新規作成は氏名・メールと祭典IDを送信する")
    func createEncodesForm() async throws {
        let pack = DistrictPack(district: AppStateFixture.district(), performances: [])
        let spy = try RecordingHTTPClientSpy(response: pack)
        var auth = AuthProviderSpy().client
        auth.getTokens = { "token" }
        let response = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = auth
        } operation: {
            try await DistrictDataFetcher().create(
                name: "New", email: "district@example.com", festivalId: "festival"
            )
        }

        #expect(response == pack)
        let call = try #require(await spy.calls().first)
        #expect(call.method == "POST")
        #expect(call.path == "/festivals/festival/districts")
        #expect(call.accessToken == "token")
        let body = try #require(call.body)
        let decoded = try JSONDecoder().decode(DistrictCreateForm.self, from: body)
        #expect(decoded.name == "New")
        #expect(decoded.email == "district@example.com")
    }

    @Test("地区アカウント再発行は地区単位のPOSTへメールを渡す")
    func reissueEncodesEmail() async throws {
        let pack = DistrictPack(district: AppStateFixture.district(), performances: [])
        let spy = try RecordingHTTPClientSpy(response: pack)
        var auth = AuthProviderSpy().client
        auth.getTokens = { "token" }
        let response = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = auth
        } operation: {
            try await DistrictDataFetcher().reissue(districtId: "district", email: "new@example.com")
        }

        #expect(response == pack)
        let call = try #require(await spy.calls().first)
        #expect(call.method == "POST")
        #expect(call.path == "/districts/district/reissue")
        let body = try #require(call.body)
        #expect(try JSONDecoder().decode(DistrictReissueForm.self, from: body).email == "new@example.com")
    }

    @Test("地区の複合更新はPUTで担当者情報を含めて保存する")
    func updateDistrictPack() async throws {
        let district = AppStateFixture.district()
        let performance = Performance(id: "performance", districtId: district.id)
        let pack = DistrictPack(district: district, performances: [performance])
        let spy = try RecordingHTTPClientSpy(response: pack)
        var auth = AuthProviderSpy().client
        auth.getTokens = { "token" }
        let result = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = auth
        } operation: {
            try await DistrictDataFetcher().update(district: district, performances: [performance])
        }

        #expect(result == pack)
        let call = try #require(await spy.calls().first)
        #expect(call.path == "/districts/district")
        #expect(call.method == "PUT")
        #expect(call.accessToken == "token")
        let encoded = try #require(call.body)
        let sentPack = try JSONDecoder().decode(DistrictPack.self, from: encoded)
        #expect(sentPack.performances == [performance])
    }

    @Test("地区基本情報だけの更新では/coreパスを使用する")
    func updateDistrictCore() async throws {
        let district = AppStateFixture.district()
        let spy = try RecordingHTTPClientSpy(response: district)
        var auth = AuthProviderSpy().client
        auth.getTokens = { "token" }
        let result = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = auth
        } operation: {
            try await DistrictDataFetcher().update(district: district)
        }

        #expect(result == district)
        let call = try #require(await spy.calls().first)
        #expect(call.path == "/districts/district/core")
        #expect(call.method == "PUT")
        #expect(call.accessToken == "token")
    }

    @Test("不正な通信レスポンスは呼び出し元にエラーとして伝える")
    func propagatesHTTPFailure() async {
        let spy = RecordingHTTPClientSpy(responseJSON: "{}", shouldFail: true)
        await #expect(throws: RecordingHTTPClientSpy.Failure.requested) {
            try await withDependencies {
                $0.installTestSpies()
                $0[HTTPClientKey.self] = spy
            } operation: {
                try await DistrictDataFetcher().fetch(districtID: "district")
            }
        }
    }
}
