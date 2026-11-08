import Dependencies

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
            body: SignUpRequest(email: email, password: password)
        )
    }

    func confirmSignUp(email: String, code: String) async throws {
        try await client.post(
            path: "/advertisers/confirm-signup",
            body: ConfirmSignUpRequest(email: email, confirmationCode: code)
        )
    }
}

private struct SignUpRequest: Encodable {
    let email: String
    let password: String
}

private struct ConfirmSignUpRequest: Encodable {
    let email: String
    let confirmationCode: String
}

enum AdvertiserAuthDataFetcherKey: DependencyKey {
    static let liveValue: any AdvertiserAuthDataFetcherProtocol = AdvertiserAuthDataFetcher()
}
