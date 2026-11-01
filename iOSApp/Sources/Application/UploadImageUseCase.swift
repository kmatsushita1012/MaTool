import Dependencies
import Foundation
import Shared

protocol UploadImageUseCaseProtocol: Sendable {
    func prepareJPEG(from data: Data) async throws -> Data
    func upload(target: ImageUploadTarget, jpegData: Data) async throws -> String
}

struct UploadImageUseCase: UploadImageUseCaseProtocol {
    @Dependency(ImageJPEGProcessingClientKey.self) private var jpegProcessor
    @Dependency(ImageUploadDataFetcherKey.self) private var dataFetcher
    @Dependency(S3ImageUploadClientKey.self) private var s3Client

    func prepareJPEG(from data: Data) async throws -> Data {
        try jpegProcessor.makeJPEG(from: data)
    }

    func upload(target: ImageUploadTarget, jpegData: Data) async throws -> String {
        let response = try await dataFetcher.issueUploadURL(
            for: ImageUploadURLRequest(target: target, contentType: "image/jpeg")
        )
        try await s3Client.put(url: response.url, jpegData: jpegData)
        return response.path
    }
}

enum UploadImageUseCaseKey: DependencyKey {
    static let liveValue: any UploadImageUseCaseProtocol = UploadImageUseCase()
}

extension DependencyValues {
    var uploadImageUseCase: any UploadImageUseCaseProtocol {
        get { self[UploadImageUseCaseKey.self] }
        set { self[UploadImageUseCaseKey.self] = newValue }
    }
}
