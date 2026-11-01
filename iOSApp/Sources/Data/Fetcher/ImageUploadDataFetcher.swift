import Dependencies
import Shared

protocol ImageUploadDataFetcherProtocol: DataFetcher {
    func issueUploadURL(for request: ImageUploadURLRequest) async throws -> ImageUploadURLResponse
}

struct ImageUploadDataFetcher: ImageUploadDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) private var client

    func issueUploadURL(for request: ImageUploadURLRequest) async throws -> ImageUploadURLResponse {
        try await client.post(
            path: "/images/upload-url",
            body: request,
            accessToken: await getToken()
        )
    }
}

enum ImageUploadDataFetcherKey: DependencyKey {
    static let liveValue: any ImageUploadDataFetcherProtocol = ImageUploadDataFetcher()
}

extension DependencyValues {
    var imageUploadDataFetcher: any ImageUploadDataFetcherProtocol {
        get { self[ImageUploadDataFetcherKey.self] }
        set { self[ImageUploadDataFetcherKey.self] = newValue }
    }
}
