import Foundation
@testable import Backend

actor ImageStorageClientSpy: ImageStorageClientProtocol {
    private(set) var presignKeys: [String] = []
    private(set) var publishCalls: [(String, String, String?)] = []
    var publishedURL = "https://cdn.example.test/image.jpg?v=1"

    func presign(key: String) async throws -> (url: URL, expiresAt: Date) {
        presignKeys.append(key)
        return (URL(string: "https://s3.example.test/upload")!, Date(timeIntervalSince1970: 1_800_000_000))
    }

    func publish(temporaryKey: String, permanentKey: String, currentURL: String?) async throws -> String {
        publishCalls.append((temporaryKey, permanentKey, currentURL))
        return publishedURL
    }
}
