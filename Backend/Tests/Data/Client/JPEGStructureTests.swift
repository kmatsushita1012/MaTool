import Foundation
import Testing
@testable import Backend

struct JPEGStructureTests {
    @Test("最小構成のSOF・SOS・EOIは正常と判定される")
    func acceptsValidMarkers() {
        let data = validJPEG()
        #expect(JPEGStructure(data: data).isValid)
        #expect(UploadedJPEGValidator.isValid(
            contentType: "image/jpeg", contentLength: data.count, data: data
        ))
    }

    @Test("SOIまたはEOIを欠くデータ、末尾にデータを追加した画像を拒否する")
    func rejectsMissingOrTrailingMarkers() {
        let base = validJPEG()
        let variants = [
            Data(), Data([0xFF, 0xD8, 0xFF]),
            Data(base.dropFirst()), Data(base.dropLast()),
            base + Data([0x00]), Data([0xFF, 0xD8, 0xFF, 0xD9])
        ]
        for data in variants {
            #expect(!JPEGStructure(data: data).isValid)
        }
    }

    @Test("JPEGマーカーの区切りと長さが不正な場合は読み進めない")
    func rejectsInvalidMarkerBoundaries() {
        for (offset, value) in [
            (2, 0x00), (3, 0xD8), (3, 0xD0),
            (4, 0x01), (5, 0x00), (5, 0xFF)
        ] {
            var data = validJPEG()
            data[offset] = UInt8(value)
            #expect(!JPEGStructure(data: data).isValid)
        }
    }

    @Test("SOFヘッダの寸法不足・Component数不整合を拒否する")
    func rejectsMalformedFrameHeader() {
        for (offset, value) in [
            (5, 0x07), (7, 0x01), (8, 0), (9, 0x01), (10, 0),
            (11, 0), (11, 2)
        ] {
            var data = validJPEG()
            data[offset] = UInt8(value)
            #expect(!JPEGStructure(data: data).isValid)
        }
    }

    @Test("画像サイズと縦横比の境界値を正しく判定する")
    func rejectsDimensionLimits() {
        for (width, height) in [
            (0, 1), (1, 0), (10_001, 1),
            (1, 10_001), (1_001, 100),
            (8_000, 6_000)
        ] {
            let data = validJPEG(width: UInt16(width), height: UInt16(height))
            #expect(!JPEGStructure(data: data).isValid)
        }
        #expect(JPEGStructure(data: validJPEG(width: 1_000, height: 100)).isValid)
        #expect(JPEGStructure(data: validJPEG(width: 10_000, height: 4_000)).isValid)
    }

    @Test("JPEGフレームのComponent ID・Sample factor・量子化テーブル違反を拒否する")
    func rejectsInvalidFrameComponents() {
        for (offset, value) in [
            (13, 0x01), (13, 0x10), (13, 0x51),
            (13, 0x15), (14, 0x04)
        ] {
            var data = validJPEG()
            data[offset] = UInt8(value)
            #expect(!JPEGStructure(data: data).isValid)
        }

        let frameWithDuplicateIDs = Data([
            0xFF, 0xD8,
            0xFF, 0xC0, 0x00, 0x0E, 0x08, 0, 1, 0, 1,
            0x02, 0x01, 0x11, 0x00, 0x01, 0x11, 0x00,
            0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,
            0x00, 0xFF, 0xD9
        ])
        #expect(!JPEGStructure(data: frameWithDuplicateIDs).isValid)
    }

    @Test("複数のSOFセグメントが現れたら不正とする")
    func rejectsRepeatedFrames() {
        let data = validJPEG()
        let frame = Data(data[2..<15])
        let duplicate = Data(data.prefix(15)) + frame + Data(data.dropFirst(15))

        #expect(!JPEGStructure(data: duplicate).isValid)
    }

    @Test("SOSがフレームより先・ヘッダ短すぎ・Component不一致なら拒否する")
    func rejectsInvalidScanHeader() {
        let base = validJPEG()
        let premature = Data(base.prefix(2)) + Data(base[15..<25]) + Data(base.dropFirst(25))
        #expect(!JPEGStructure(data: premature).isValid)

        for (offset, value) in [
            (18, 0x05), (19, 0), (19, 2),
            (20, 2), (21, 0x40), (21, 0x04)
        ] {
            var data = base
            data[offset] = UInt8(value)
            #expect(!JPEGStructure(data: data).isValid)
        }
    }

    @Test("スキャン内のFF00エスケープとRestart markerは有効と判定する")
    func acceptsEntropyEscapesAndRestartMarkers() {
        let base = validJPEG()
        let data = Data(base.prefix(25)) + Data([
            0xFF, 0x00, 0x12, 0xFF, 0xD0, 0x34,
            0xFF, 0xD1, 0x00
        ]) + Data(base.suffix(2))

        #expect(JPEGStructure(data: data).isValid)
    }

    @Test("SOFの複数種類とAPPセグメントは安全にスキップできる")
    func supportsAlternateFramesAndApplicationMarkers() {
        let base = validJPEG()
        var progressive = base
        progressive[3] = 0xC2
        #expect(JPEGStructure(data: progressive).isValid)

        let withAPP = Data(base.prefix(2)) +
            Data([0xFF, 0xE1, 0x00, 0x04, 0x11, 0x22]) +
            Data(base.dropFirst(2))
        #expect(JPEGStructure(data: withAPP).isValid)
    }

    @Test("Content-Type・サイズの入力チェックはNULL/0/容量超過を拒否する")
    func validatorHandlesAllMetadataFailures() {
        let data = validJPEG()

        #expect(!UploadedJPEGValidator.isValid(contentType: nil, contentLength: data.count, data: data))
        #expect(!UploadedJPEGValidator.isValid(contentType: "image/jpeg", contentLength: nil, data: data))
        #expect(!UploadedJPEGValidator.isValid(contentType: "image/jpeg", contentLength: 0, data: data))
        #expect(!UploadedJPEGValidator.isValid(
            contentType: "image/jpeg",
            contentLength: UploadedJPEGValidator.maximumBytes + 1,
            data: data
        ))
        #expect(!UploadedJPEGValidator.isValid(
            contentType: "image/jpeg",
            contentLength: data.count - 1,
            data: data
        ))
    }

    private func validJPEG(width: UInt16 = 1, height: UInt16 = 1) -> Data {
        Data([
            0xFF, 0xD8,
            0xFF, 0xC0, 0x00, 0x0B, 0x08,
            UInt8(height >> 8), UInt8(height & 0xFF),
            UInt8(width >> 8), UInt8(width & 0xFF),
            0x01, 0x01, 0x11, 0x00,
            0xFF, 0xDA, 0x00, 0x08,
            0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,
            0x00,
            0xFF, 0xD9
        ])
    }
}
