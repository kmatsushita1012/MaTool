import Dependencies
import Foundation

protocol S3ImageUploadClientProtocol: Sendable {
    func put(url: String, jpegData: Data) async throws
}

struct S3ImageUploadClient: S3ImageUploadClientProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func put(url: String, jpegData: Data) async throws {
        guard let url = URL(string: url), url.scheme == "https" else {
            throw S3ImageUploadError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = jpegData

        let (_, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw S3ImageUploadError.invalidResponse
        }
        guard (200...299).contains(response.statusCode) else {
            throw S3ImageUploadError.rejected(response.statusCode)
        }
    }
}

enum S3ImageUploadError: Error, Equatable, LocalizedError {
    case invalidURL
    case invalidResponse
    case rejected(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "署名付きアップロード URL が不正です。"
        case .invalidResponse:
            "S3 から有効な応答を受け取れませんでした。"
        case .rejected(let statusCode):
            "画像のアップロードに失敗しました。(HTTP \(statusCode))"
        }
    }
}

enum S3ImageUploadClientKey: DependencyKey {
    static let liveValue: any S3ImageUploadClientProtocol = S3ImageUploadClient()
}

extension DependencyValues {
    var s3ImageUploadClient: any S3ImageUploadClientProtocol {
        get { self[S3ImageUploadClientKey.self] }
        set { self[S3ImageUploadClientKey.self] = newValue }
    }
}
