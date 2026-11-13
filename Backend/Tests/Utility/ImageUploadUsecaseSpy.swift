import Foundation
import Shared
@testable import Backend

actor ImageUploadUsecaseSpy: ImageUploadUsecaseProtocol {
    private(set) var requests: [(ImageUploadURLRequest, UserRole)] = []
    private let result: ImageUploadURLResponse
    private let shouldFail: Bool

    init(
        result: ImageUploadURLResponse = .init(
            url: "https://upload.example.test/signed",
            path: "temporary/festivals/festival/light.jpg",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        ),
        shouldFail: Bool = false
    ) {
        self.result = result
        self.shouldFail = shouldFail
    }

    func issue(_ request: ImageUploadURLRequest, user: UserRole) async throws -> ImageUploadURLResponse {
        requests.append((request, user))
        if shouldFail { throw TestError.intentional }
        return result
    }

    func recordedRequests() -> [(ImageUploadURLRequest, UserRole)] { requests }
}
