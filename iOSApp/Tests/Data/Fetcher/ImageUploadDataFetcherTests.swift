import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

struct ImageUploadDataFetcherTests {
    @Test("共通署名 URL API を既存 HTTP Client と認証トークンで呼び出す")
    func requestsUploadURL() async throws {
        let target = ImageUploadTarget(type: .festival, id: "festival-1", variant: .dark)
        let request = ImageUploadURLRequest(target: target, contentType: "image/jpeg")
        let response = ImageUploadURLResponse(
            url: "https://upload.example/signed",
            path: "temporary/festivals/festival-1/dark.jpg",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let client = HTTPClientSpy(responseData: try encoder.encode(response))

        let result = try await withDependencies {
            $0[HTTPClientKey.self] = client
            $0.authProvider = authProvider(token: "test-token")
            $0.values = .testFixture
        } operation: {
            try await ImageUploadDataFetcher().issueUploadURL(for: request)
        }

        #expect(result.path == response.path)
        let calls = await client.postCalls
        #expect(calls.count == 1)
        #expect(calls.first?.path == "/images/upload-url")
        #expect(calls.first?.accessToken == "test-token")
        let sent = try JSONDecoder().decode(ImageUploadURLRequest.self, from: #require(calls.first?.body))
        #expect(sent.target == target)
        #expect(sent.contentType == "image/jpeg")
    }


    @Test("トークン取得が失敗しても通信処理はnilトークンで委譲する")
    func failedTokenLookupUsesNilHeader() async throws {
        let target = ImageUploadTarget(type: .festival, id: "festival", variant: .light)
        let request = ImageUploadURLRequest(target: target, contentType: "image/jpeg")
        let expected = ImageUploadURLResponse(
            url: "https://example.com/upload", path: "temporary/upload.jpg",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let spy = try RecordingHTTPClientSpy(response: expected)
        var auth = authProvider(token: "unused")
        auth.getTokens = { throw FetcherTestError.failed }

        let result = try await withDependencies {
            $0.installTestSpies()
            $0[HTTPClientKey.self] = spy
            $0.authProvider = auth
        } operation: {
            try await ImageUploadDataFetcher().issueUploadURL(for: request)
        }

        #expect(result.path == expected.path)
        let calls = await spy.calls()
        #expect(calls.map(\.method) == ["POST"])
        #expect(calls.first?.accessToken == nil)
    }

    @Test("署名URL発行のHTTP障害は成功を装わずそのまま通知する")
    func uploadURLRequestFailurePropagates() async {
        let target = ImageUploadTarget(type: .district, id: "district", variant: .dark)
        let request = ImageUploadURLRequest(target: target, contentType: "image/jpeg")
        let spy = RecordingHTTPClientSpy(responseJSON: "{}", shouldFail: true)

        await #expect(throws: RecordingHTTPClientSpy.Failure.requested) {
            try await withDependencies {
                $0.installTestSpies()
                $0[HTTPClientKey.self] = spy
                $0.authProvider = tokenProvidingAuthProvider()
            } operation: {
                try await ImageUploadDataFetcher().issueUploadURL(for: request)
            }
        }
        #expect(await spy.calls().map(\.path) == ["/images/upload-url"])
    }


    @Test("依存コンテナに差し替えた署名URLFetcherが呼び出される")
    func injectedFetcherIsUsed() async throws {
        let expected = ImageUploadURLResponse(
            url: "https://example.com/injected",
            path: "temporary/injected.jpg",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let spy = ImageUploadDataFetcherSpy(response: expected)
        let target = ImageUploadTarget(type: .festival, id: "festival", variant: .light)
        let request = ImageUploadURLRequest(target: target, contentType: "image/jpeg")

        let actual = try await withDependencies {
            $0.imageUploadDataFetcher = spy
        } operation: {
            @Dependency(\.imageUploadDataFetcher) var fetcher
            return try await fetcher.issueUploadURL(for: request)
        }

        #expect(actual.path == expected.path)
        #expect(await spy.requestCount == 1)
    }

    private func authProvider(token: String) -> AuthProvider {
        AuthProvider(
            initialize: {},
            signIn: { _, _ in throw SpyInvocationError.unexpected("signIn") },
            confirmSignIn: { _ in throw SpyInvocationError.unexpected("confirmSignIn") },
            getUserRole: { throw SpyInvocationError.unexpected("getUserRole") },
            getTokens: { token },
            signOut: { throw SpyInvocationError.unexpected("signOut") },
            changePassword: { _, _ in throw SpyInvocationError.unexpected("changePassword") },
            resetPassword: { _ in throw SpyInvocationError.unexpected("resetPassword") },
            confirmResetPassword: { _, _, _ in throw SpyInvocationError.unexpected("confirmResetPassword") },
            updateEmail: { _ in throw SpyInvocationError.unexpected("updateEmail") },
            confirmUpdateEmail: { _ in throw SpyInvocationError.unexpected("confirmUpdateEmail") }
        )
    }
}

private actor ImageUploadDataFetcherSpy: ImageUploadDataFetcherProtocol {
    let response: ImageUploadURLResponse
    private(set) var requestCount = 0

    init(response: ImageUploadURLResponse) {
        self.response = response
    }

    func issueUploadURL(for request: ImageUploadURLRequest) async throws -> ImageUploadURLResponse {
        requestCount += 1
        return response
    }
}
