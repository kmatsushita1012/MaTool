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
    @Test("HTTP 200と299は成功、それ以外は拒否とする")
    func handlesSuccessAndFailureBoundaries() async throws {
        let session = S3ResponseURLProtocolSpy.session()
        let client = S3ImageUploadClient(session: session)

        try await client.put(url: "https://image-upload.invalid/200", jpegData: Data([1]))
        try await client.put(url: "https://image-upload.invalid/299", jpegData: Data([2]))
        await #expect(throws: S3ImageUploadError.rejected(300)) {
            try await client.put(url: "https://image-upload.invalid/300", jpegData: Data())
        }
        await #expect(throws: S3ImageUploadError.rejected(500)) {
            try await client.put(url: "https://image-upload.invalid/500", jpegData: Data())
        }
    }

    @Test("URLSessionからHTTP以外のレスポンスを受けた場合は不正と判定する")
    func rejectsNonHTTPResponse() async {
        let client = S3ImageUploadClient(session: S3ResponseURLProtocolSpy.session())

        await #expect(throws: S3ImageUploadError.invalidResponse) {
            try await client.put(url: "https://image-upload.invalid/non-http", jpegData: Data([1]))
        }
    }

    @Test("通信経路の障害はアップロードが成功したことにしない")
    func propagatesSessionFailure() async {
        let client = S3ImageUploadClient(session: S3ResponseURLProtocolSpy.session())

        await #expect(throws: URLError.self) {
            try await client.put(url: "https://image-upload.invalid/offline", jpegData: Data([1]))
        }
    }

    @Test("不正URLとS3エラーの説明には正しい回復情報がある")
    func allErrorDescriptionsAreMeaningful() {
        #expect(S3ImageUploadError.invalidURL.errorDescription?.contains("URL") == true)
        #expect(S3ImageUploadError.invalidResponse.errorDescription?.contains("応答") == true)
        #expect(S3ImageUploadError.rejected(403).errorDescription?.contains("403") == true)
    }

    @Test("ftpなどHTTPS以外のスキームはネットワーク要求前に拒否する")
    func rejectsOtherSchemesBeforeCreatingRequest() async {
        let client = S3ImageUploadClient(session: S3ResponseURLProtocolSpy.session())

        for address in ["ftp://example.com/file", "not-a-url", ""] {
            await #expect(throws: S3ImageUploadError.invalidURL) {
                try await client.put(url: address, jpegData: Data())
            }
        }
    }

}
