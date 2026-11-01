import Foundation
@testable import Backend

actor ImageStorageClientSpy: ImageStorageClientProtocol {
    init(validationFailures: Set<String> = [], temporaryImageData: [String: Data] = [:]) {
        self.validationFailures = validationFailures
        self.temporaryImageData = temporaryImageData
    }

    private(set) var presignKeys: [String] = []
    private(set) var validationKeys: [String] = []
    private(set) var publishCalls: [(String, String, String?)] = []
    private(set) var events: [String] = []
    private let validationFailures: Set<String>
    private let temporaryImageData: [String: Data]
    var publishedURL = "https://cdn.example.test/image.jpg?v=1"

    func presign(key: String) async throws -> (url: URL, expiresAt: Date) {
        presignKeys.append(key)
        return (URL(string: "https://s3.example.test/upload")!, Date(timeIntervalSince1970: 1_800_000_000))
    }

    func validateTemporaryImage(key: String) async throws {
        validationKeys.append(key)
        events.append("validate:\(key)")
        if validationFailures.contains(key) || temporaryImageData[key].map({
            !UploadedJPEGValidator.isValid(contentType: "image/jpeg", contentLength: $0.count, data: $0)
        }) == true {
            throw Error.badRequest("テスト用の一時画像検証エラー")
        }
    }

    func publish(temporaryKey: String, permanentKey: String, currentURL: String?) async throws -> String {
        publishCalls.append((temporaryKey, permanentKey, currentURL))
        events.append("publish:\(temporaryKey)")
        return publishedURL
    }
}
