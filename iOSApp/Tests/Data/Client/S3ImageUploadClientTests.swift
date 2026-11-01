import Foundation
import Testing
@testable import iOSApp

struct S3ImageUploadClientTests {
    @Test("署名 URL へ JPEG を直接 PUT し、認証ヘッダーを付けず非 2xx を拒否する")
    func putsSignedURLWithoutBearerToken() async throws {
        ImageUploadURLProtocolSpy.configure(statusCode: 204)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ImageUploadURLProtocolSpy.self]
        let session = URLSession(configuration: configuration)
        let data = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let client = S3ImageUploadClient(session: session)

        try await client.put(url: "https://upload.example/signed?signature=abc", jpegData: data)

        let request = ImageUploadURLProtocolSpy.lastRequest
        #expect(request?.httpMethod == "PUT")
        #expect(request?.value(forHTTPHeaderField: "Content-Type") == "image/jpeg")
        #expect(request?.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(ImageUploadURLProtocolSpy.lastBody == data)

        ImageUploadURLProtocolSpy.configure(statusCode: 403)
        await #expect(throws: S3ImageUploadError.rejected(403)) {
            try await client.put(url: "https://upload.example/signed?signature=expired", jpegData: Data([1]))
        }
    }

    @Test("HTTPS 以外の URL を拒否する")
    func rejectsNonHTTPSURL() async {
        let client = S3ImageUploadClient()
        await #expect(throws: S3ImageUploadError.invalidURL) {
            try await client.put(url: "http://upload.example/signed", jpegData: Data([1]))
        }
    }
}
