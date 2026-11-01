import CoreGraphics
import Dependencies
import Foundation
import ImageIO
import UniformTypeIdentifiers

protocol ImageJPEGProcessingClientProtocol: Sendable {
    func makeJPEG(from data: Data) throws -> Data
}

struct ImageJPEGProcessingClient: ImageJPEGProcessingClientProtocol {
    private let maximumBytes = 10 * 1_024 * 1_024
    private let maximumDimension = 10_000
    private let maximumPixelCount = 40_000_000
    private let maximumAspectRatio = 10.0

    func makeJPEG(from data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else {
            throw ImageJPEGProcessingError.invalidImage
        }

        for maximumPixelSize in [10_000, 8_000, 6_400, 5_120, 4_096, 3_072, 2_048, 1_536, 1_024] {
            guard let image = makeThumbnail(source: source, maximumPixelSize: maximumPixelSize) else {
                continue
            }
            guard isWithinDimensionAndAspectLimits(image) else {
                throw ImageJPEGProcessingError.invalidDimensions
            }
            guard image.width * image.height <= maximumPixelCount else { continue }

            for quality in [0.9, 0.78, 0.66, 0.54, 0.42, 0.3] {
                guard let jpeg = encode(image, quality: quality) else {
                    continue
                }
                if jpeg.count <= maximumBytes {
                    return jpeg
                }
            }
        }

        throw ImageJPEGProcessingError.imageTooLarge
    }

    private func makeThumbnail(source: CGImageSource, maximumPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private func isWithinDimensionAndAspectLimits(_ image: CGImage) -> Bool {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0,
              width <= maximumDimension, height <= maximumDimension else {
            return false
        }
        return Double(max(width, height)) / Double(min(width, height)) <= maximumAspectRatio
    }

    private func encode(_ image: CGImage, quality: Double) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

enum ImageJPEGProcessingError: Error, Equatable, LocalizedError {
    case invalidImage
    case invalidDimensions
    case imageTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "画像を読み込めませんでした。別の画像を選択してください。"
        case .invalidDimensions:
            "画像の縦横比またはサイズが上限を超えています。"
        case .imageTooLarge:
            "画像をアップロード可能なサイズに圧縮できませんでした。"
        }
    }
}

enum ImageJPEGProcessingClientKey: DependencyKey {
    static let liveValue: any ImageJPEGProcessingClientProtocol = ImageJPEGProcessingClient()
}

extension DependencyValues {
    var imageJPEGProcessingClient: any ImageJPEGProcessingClientProtocol {
        get { self[ImageJPEGProcessingClientKey.self] }
        set { self[ImageJPEGProcessingClientKey.self] = newValue }
    }
}
