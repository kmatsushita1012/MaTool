import Foundation
import Testing
@testable import Backend

struct S3ImageClientTests {
    @Test("構造が正しいJPEGを受け入れる")
    func acceptsStructurallyValidJPEG() {
        let data = jpeg(width: 1, height: 1)

        #expect(UploadedJPEGValidator.isValid(
            contentType: "image/jpeg",
            contentLength: data.count,
            data: data
        ))
    }

    @Test("不正なSOFとSOSを含む18 byte JPEGを拒否する")
    func rejectsMalformed18ByteJPEG() {
        let data = Data([
            0xFF, 0xD8, 0xFF, 0xC0, 0x00, 0x08, 0x08, 0x00, 0x01,
            0x00, 0x01, 0x00, 0xFF, 0xDA, 0x00, 0x02, 0xFF, 0xD9
        ])

        #expect(data.count == 18)
        #expect(!UploadedJPEGValidator.isValid(
            contentType: "image/jpeg",
            contentLength: data.count,
            data: data
        ))
    }

    @Test("10MiB超・Content-Type不一致・長さ不一致を拒否する")
    func rejectsInvalidMetadataAndOversizedImage() {
        let valid = jpeg(width: 1, height: 1)
        let oversized = Data(repeating: 0, count: Int(UploadedJPEGValidator.maximumBytes) + 1)

        #expect(!UploadedJPEGValidator.isValid(
            contentType: "image/jpeg",
            contentLength: oversized.count,
            data: oversized
        ))
        #expect(!UploadedJPEGValidator.isValid(
            contentType: "image/png",
            contentLength: valid.count,
            data: valid
        ))
        #expect(!UploadedJPEGValidator.isValid(
            contentType: "image/jpeg",
            contentLength: valid.count + 1,
            data: valid
        ))
    }

    @Test("画素数・縦横比の上限を超えるJPEGを拒否する")
    func rejectsExcessiveDimensions() {
        for data in [
            jpeg(width: 8_000, height: 6_000),
            jpeg(width: 1_001, height: 100),
            jpeg(width: 10_001, height: 1_000)
        ] {
            #expect(!UploadedJPEGValidator.isValid(
                contentType: "image/jpeg",
                contentLength: data.count,
                data: data
            ))
        }
    }
}

private extension S3ImageClientTests {
    func jpeg(width: UInt16, height: UInt16) -> Data {
        Data([
            0xFF, 0xD8,
            0xFF, 0xC0, 0x00, 0x0B, 0x08,
            UInt8(height >> 8), UInt8(height & 0xFF),
            UInt8(width >> 8), UInt8(width & 0xFF),
            0x01, 0x01, 0x11, 0x00,
            0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,
            0x00,
            0xFF, 0xD9
        ])
    }
}
