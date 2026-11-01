import AWSS3
import Dependencies
import Foundation

enum S3ImageClientKey: DependencyKey {
    static let liveValue: any S3ImageClientProtocol = S3ImageClient()
}

protocol S3ImageClientProtocol: Sendable {
    func presign(key: String) async throws -> (url: URL, expiresAt: Date)
    func publish(temporaryKey: String, permanentKey: String, currentURL: String?) async throws -> String
}

struct S3ImageClient: S3ImageClientProtocol {
    private let bucket = ProcessInfo.processInfo.environment["IMAGE_UPLOAD_BUCKET"] ?? ""
    private let publicBaseURL = ProcessInfo.processInfo.environment["IMAGE_PUBLIC_BASE_URL"] ?? ""

    func presign(key: String) async throws -> (url: URL, expiresAt: Date) {
        guard !bucket.isEmpty else { throw Error.internalServerError("IMAGE_UPLOAD_BUCKET が未設定です。") }
        let client = try await S3Client()
        let input = PutObjectInput(bucket: bucket, contentType: "image/jpeg", key: key)
        let url = try await client.presignedURLForPutObject(input: input, expiration: 900)
        return (url, Date().addingTimeInterval(900))
    }

    func publish(temporaryKey: String, permanentKey: String, currentURL: String?) async throws -> String {
        guard !bucket.isEmpty, let base = URL(string: publicBaseURL), base.scheme == "https" else {
            throw Error.internalServerError("画像ストレージの公開 URL が未設定です。")
        }
        let client = try await S3Client()
        let head = try await client.headObject(input: .init(bucket: bucket, key: temporaryKey))
        guard head.contentType == "image/jpeg", let size = head.contentLength,
              size > 0, size <= 10 * 1_024 * 1_024 else { throw Error.badRequest("画像形式または容量が不正です。") }
        let object = try await client.getObject(input: .init(bucket: bucket, key: temporaryKey))
        guard let body = try await object.body?.readData(), JPEGStructure(data: body).isValid else {
            throw Error.badRequest("JPEG 画像の構造または画素数が不正です。")
        }
        _ = try await client.copyObject(input: .init(bucket: bucket, contentType: "image/jpeg", copySource: "\(bucket)/\(temporaryKey)", key: permanentKey, metadataDirective: .replace))
        let components = URLComponents(url: base.appending(path: permanentKey), resolvingAgainstBaseURL: false)
        let previous = currentURL.flatMap { URLComponents(string: $0)?.queryItems?.first(where: { $0.name == "v" })?.value }.flatMap(UInt64.init) ?? 0
        let version = max(UInt64(Date().timeIntervalSince1970 * 1_000), previous + 1)
        guard var urlComponents = components else { throw Error.internalServerError("画像 URL を構築できません。") }
        urlComponents.queryItems = (urlComponents.queryItems ?? []).filter { $0.name != "v" } + [URLQueryItem(name: "v", value: String(version))]
        guard let url = urlComponents.url else { throw Error.internalServerError("画像 URL を構築できません。") }
        return url.absoluteString
    }
}

private struct JPEGStructure {
    let data: Data
    init(data: Data) { self.data = data }

    var isValid: Bool {
        let bytes = [UInt8](data)
        guard bytes.count >= 4, bytes[0] == 0xFF, bytes[1] == 0xD8 else { return false }
        var index = 2
        var dimensions: (Int, Int)?
        var sawScan = false
        while index < bytes.count {
            guard bytes[index] == 0xFF else { return false }
            while index < bytes.count, bytes[index] == 0xFF { index += 1 }
            guard index < bytes.count else { return false }
            let marker = bytes[index]; index += 1
            if marker == 0xD9 { return sawScan && dimensions != nil && index == bytes.count }
            if marker == 0xD8 || marker == 0x00 || (0xD0...0xD7).contains(marker) { return false }
            guard index + 2 <= bytes.count else { return false }
            let length = Int(bytes[index]) << 8 | Int(bytes[index + 1])
            guard length >= 2, index + length <= bytes.count else { return false }
            if [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF].contains(marker) {
                guard length >= 8 else { return false }
                let height = Int(bytes[index + 3]) << 8 | Int(bytes[index + 4])
                let width = Int(bytes[index + 5]) << 8 | Int(bytes[index + 6])
                guard width > 0, height > 0, width <= 10_000, height <= 10_000,
                      width * height <= 40_000_000,
                      max(width, height) <= min(width, height) * 10 else { return false }
                dimensions = (width, height)
            }
            index += length
            if marker == 0xDA {
                sawScan = true
                while index + 1 < bytes.count {
                    if bytes[index] != 0xFF { index += 1; continue }
                    let next = bytes[index + 1]
                    if next == 0x00 || (0xD0...0xD7).contains(next) { index += 2; continue }
                    break
                }
            }
        }
        return false
    }
}
