import Foundation
@testable import Backend

actor ImageStorageClientSpy: ImageStorageClientProtocol {
    init(validationFailures: Set<String> = []) {
        self.validationFailures = validationFailures
    }

    private(set) var presignKeys: [String] = []
    private(set) var validationKeys: [String] = []
    private(set) var publishCalls: [(String, String, String?)] = []
    private(set) var events: [String] = []
    private let validationFailures: Set<String>
    var publishedURL = "https://cdn.example.test/image.jpg?v=1"

    func presign(key: String) async throws -> (url: URL, expiresAt: Date) {
        presignKeys.append(key)
        return (URL(string: "https://s3.example.test/upload")!, Date(timeIntervalSince1970: 1_800_000_000))
    }

    func validateTemporaryImage(key: String) async throws {
        validationKeys.append(key)
        events.append("validate:\(key)")
        if validationFailures.contains(key) {
            throw Error.badRequest("テスト用の一時画像検証エラー")
        }
    }

    func publish(temporaryKey: String, permanentKey: String, currentURL: String?) async throws -> String {
        publishCalls.append((temporaryKey, permanentKey, currentURL))
        events.append("publish:\(temporaryKey)")
        return publishedURL
    }
}
