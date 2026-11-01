import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

struct UploadImageUseCaseTests {
    @Test("JPEG 化を経由し、署名 URL 取得後に S3 PUT する")
    func preparesAndUploadsImage() async throws {
        let source = Data([1, 2, 3])
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let processor = ImageJPEGProcessingClientSpy(output: jpeg)
        let target = ImageUploadTarget(type: .district, id: "district-1", variant: .light)
        let fetcher = ImageUploadDataFetcherSpy(response: ImageUploadURLResponse(
            url: "https://upload.example/signed",
            path: "temporary/districts/district-1/light.jpg",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        ))
        let s3 = S3ImageUploadClientSpy()

        let result = try await withDependencies {
            $0[ImageJPEGProcessingClientKey.self] = processor
            $0[ImageUploadDataFetcherKey.self] = fetcher
            $0[S3ImageUploadClientKey.self] = s3
        } operation: {
            let useCase = UploadImageUseCase()
            let prepared = try await useCase.prepareJPEG(from: source)
            #expect(prepared == jpeg)
            return try await useCase.upload(target: target, jpegData: prepared)
        }

        #expect(result == "temporary/districts/district-1/light.jpg")
        #expect(processor.inputs == [source])
        #expect(await fetcher.requests == [ImageUploadURLRequest(target: target, contentType: "image/jpeg")])
        #expect(await s3.calls == [.init(url: "https://upload.example/signed", data: jpeg)])
    }
}
