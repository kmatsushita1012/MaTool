import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

struct EditionDataFetcherTests {
    @Test("Edition一覧はv1のFestival年度APIから取得する")
    func fetchListUsesV1Path() async throws {
        let edition = makeEdition()
        let response = EditionListResponse(editions: [edition], activeEditionId: nil)
        let client = try RecordingHTTPClientSpy(response: response)
        let result = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = client
            $0.authProvider = tokenProvidingAuthProvider()
        } operation: {
            try await EditionDataFetcher().fetchList(festivalID: edition.festivalId)
        }

        #expect(result == response)
        let call = try #require(await client.calls().first)
        #expect(call.method == "GET")
        #expect(call.path == "/v1/festivals/festival/editions")
    }

    @Test("Edition作成は年度Formをv1 APIへ送る")
    func createUsesV1PathAndForm() async throws {
        let edition = makeEdition()
        let response = EditionPack(edition: edition, periods: [])
        let client = try RecordingHTTPClientSpy(response: response)
        let result = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = client
            $0.authProvider = tokenProvidingAuthProvider()
        } operation: {
            try await EditionDataFetcher().create(festivalID: "festival", year: 2026)
        }

        #expect(result == response)
        let call = try #require(await client.calls().first)
        #expect(call.method == "POST")
        #expect(call.path == "/v1/festivals/festival/editions")
        let body = try #require(call.body)
        #expect(try JSONDecoder().decode(EditionCreateForm.self, from: body).year == 2026)
    }

    @Test("EditionPackの取得・保存は年度をパスに含める")
    func fetchAndUpdateUseYearPaths() async throws {
        let edition = makeEdition()
        let pack = EditionPack(edition: edition, periods: [])

        let fetchClient = try RecordingHTTPClientSpy(response: pack)
        let fetchResult = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = fetchClient
            $0.authProvider = tokenProvidingAuthProvider()
        } operation: {
            try await EditionDataFetcher().fetch(festivalID: "festival", year: 2026)
        }
        #expect(fetchResult == pack)
        let fetchCall = try #require(await fetchClient.calls().first)
        #expect(fetchCall.method == "GET")
        #expect(fetchCall.path == "/v1/festivals/festival/editions/2026")

        let updateClient = try RecordingHTTPClientSpy(response: pack)
        let updateResult = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = updateClient
            $0.authProvider = tokenProvidingAuthProvider()
        } operation: {
            try await EditionDataFetcher().update(pack)
        }
        #expect(updateResult == pack)
        let updateCall = try #require(await updateClient.calls().first)
        #expect(updateCall.method == "PUT")
        #expect(updateCall.path == "/v1/festivals/festival/editions/2026")
        #expect(try JSONDecoder().decode(EditionPack.self, from: try #require(updateCall.body)) == pack)
    }

    @Test("有効化はActiveEditionUpdateFormを独立APIへ送る")
    func activateUsesSeparateV1Path() async throws {
        let active = ActiveEdition(festivalId: "festival", editionId: "edition")
        let client = try RecordingHTTPClientSpy(response: active)
        let result = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = client
            $0.authProvider = tokenProvidingAuthProvider()
        } operation: {
            try await EditionDataFetcher().activate(festivalID: "festival", editionID: "edition")
        }

        #expect(result == active)
        let call = try #require(await client.calls().first)
        #expect(call.method == "PUT")
        #expect(call.path == "/v1/festivals/festival/active-edition")
        #expect(try JSONDecoder().decode(ActiveEditionUpdateForm.self, from: try #require(call.body)).editionId == "edition")
    }

    private func makeEdition() -> Edition {
        Edition(id: "edition", festivalId: "festival", year: 2026)
    }
}
