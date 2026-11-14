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
    @Test("JPEGの先頭マーカー・終端マーカー・余分な末尾データを検証する")
    func rejectsInvalidMarkerBoundaries() {
        let original = jpeg(width: 1, height: 1)
        var invalidStart = original
        invalidStart[0] = 0x00
        var missingStart = original
        missingStart.removeFirst(2)
        var trailingBytes = original
        trailingBytes.append(contentsOf: [0x00, 0x01])
        var missingEnd = original
        missingEnd.removeLast(2)
        var unexpectedRestart = original
        unexpectedRestart[3] = 0xD0

        for data in [Data(), Data([0xFF, 0xD8, 0xFF]), invalidStart,
                     missingStart, trailingBytes, missingEnd, unexpectedRestart] {
            #expect(!UploadedJPEGValidator.isValid(
                contentType: "image/jpeg", contentLength: data.count, data: data
            ))
        }
    }

    @Test("SOFのゼロ次元・コンポーネント数・サンプリング係数・量子化テーブルを拒否する")
    func rejectsInvalidFrameParameters() {
        for (offset, replacement) in [
            (8, UInt8(0)), (10, 0),
            (11, 0), (13, 0), (13, 0x50), (14, 4), (5, 0x04)
        ] {
            var data = jpeg(width: 1, height: 1)
            data[offset] = replacement
            #expect(!UploadedJPEGValidator.isValid(
                contentType: "image/jpeg", contentLength: data.count, data: data
            ))
        }
    }

    @Test("SOSの長さ・参照先コンポーネント・ハフマン表指定を拒否する")
    func rejectsInvalidScanParameters() {
        for (offset, replacement) in [
            (18, UInt8(0)), (19, 0), (20, 3), (21, 0x40)
        ] {
            var data = jpeg(width: 1, height: 1)
            data[offset] = replacement
            #expect(!UploadedJPEGValidator.isValid(
                contentType: "image/jpeg", contentLength: data.count, data: data
            ))
        }
    }

    @Test("エントロピー領域のエスケープ済みFFとリスタートマーカーを許容する")
    func acceptsEscapedEntropyAndRestartMarkers() {
        for marker in [UInt8(0x00), 0xD0, 0xD7] {
            var data = jpeg(width: 1, height: 1)
            data.insert(contentsOf: [0xFF, marker], at: data.count - 2)
            #expect(UploadedJPEGValidator.isValid(
                contentType: "image/jpeg", contentLength: data.count, data: data
            ))
        }
    }

    @Test("ファイルサイズ・Content-Typeのnilとゼロ長を区別して拒否する")
    func rejectsMissingMetadata() {
        let data = jpeg(width: 1, height: 1)
        #expect(!UploadedJPEGValidator.isValid(
            contentType: nil, contentLength: data.count, data: data
        ))
        #expect(!UploadedJPEGValidator.isValid(
            contentType: "image/jpeg", contentLength: nil, data: data
        ))
        #expect(!UploadedJPEGValidator.isValid(
            contentType: "image/jpeg", contentLength: 0, data: data
        ))
        #expect(!UploadedJPEGValidator.isValid(
            contentType: "image/jpeg", contentLength: -1, data: data
        ))
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
