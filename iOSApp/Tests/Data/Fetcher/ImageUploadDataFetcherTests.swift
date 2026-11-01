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
