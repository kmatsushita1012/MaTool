import Dependencies
import Shared

extension DependencyValues {
    var advertiserAuthDataFetcher: any AdvertiserAuthDataFetcherProtocol {
        get { self[AdvertiserAuthDataFetcherKey.self] }
        set { self[AdvertiserAuthDataFetcherKey.self] = newValue }
    }
}

protocol AdvertiserAuthDataFetcherProtocol: DataFetcher {
    func signUp(email: String, password: String) async throws
    func confirmSignUp(email: String, code: String) async throws
}

struct AdvertiserAuthDataFetcher: AdvertiserAuthDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) private var client

    func signUp(email: String, password: String) async throws {
        try await client.post(
            path: "/advertisers/signup",
            body: AdvertiserSignUpRequest(email: email, password: password)
        )
    }

    func confirmSignUp(email: String, code: String) async throws {
        try await client.post(
            path: "/advertisers/confirm-signup",
            body: AdvertiserConfirmSignUpRequest(email: email, confirmationCode: code)
        )
    }
}

enum AdvertiserAuthDataFetcherKey: DependencyKey {
    static let liveValue: any AdvertiserAuthDataFetcherProtocol = AdvertiserAuthDataFetcher()
}
