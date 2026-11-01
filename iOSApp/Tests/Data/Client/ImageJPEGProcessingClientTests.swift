import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import iOSApp

struct ImageJPEGProcessingClientTests {
    @Test("画像を JPEG に変換して共通容量・画素数制限に収める")
    func createsValidJPEG() throws {
        let input = try makeJPEG(width: 80, height: 40)
        let jpeg = try ImageJPEGProcessingClient().makeJPEG(from: input)

        #expect(jpeg.count <= 10 * 1_024 * 1_024)
        #expect(jpeg.starts(with: [0xFF, 0xD8]))
        let source = CGImageSourceCreateWithData(jpeg as CFData, nil)
        let image = source.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
        #expect(image?.width == 80)
        #expect(image?.height == 40)
    }

    @Test("縦横比が共通上限を超える画像を拒否する")
    func rejectsInvalidAspectRatio() throws {
        let input = try makeJPEG(width: 101, height: 10)

        #expect(throws: ImageJPEGProcessingError.invalidDimensions) {
            try ImageJPEGProcessingClient().makeJPEG(from: input)
        }
    }

    @Test("画像として解釈できないデータを拒否する")
    func rejectsInvalidData() {
        #expect(throws: ImageJPEGProcessingError.invalidImage) {
            try ImageJPEGProcessingClient().makeJPEG(from: Data([1, 2, 3]))
        }
    }

    private func makeJPEG(width: Int, height: Int) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else {
            throw ImageJPEGProcessingError.invalidImage
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageJPEGProcessingError.invalidImage
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageJPEGProcessingError.invalidImage
        }
        return data as Data
    }
}
