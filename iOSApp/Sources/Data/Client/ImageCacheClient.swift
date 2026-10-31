import Dependencies
import Foundation
import Kingfisher

protocol ImageCacheClientProtocol: Sendable {
    func preload(paths: [String?]) async
}

actor ImageCacheClient: ImageCacheClientProtocol {
    func preload(paths: [String?]) async {
        var loadedURLs = Set<URL>()
        for url in paths.compactMap({ Self.url(from: $0) }) where loadedURLs.insert(url).inserted {
            _ = try? await KingfisherManager.shared.retrieveImage(
                with: url,
                options: [.cacheOriginalImage]
            )
        }
    }

    private static func url(from path: String?) -> URL? {
        guard let path,
              let url = URL(string: path),
              url.scheme != nil else {
            return nil
        }
        return url
    }
}

enum ImageCacheClientKey: DependencyKey {
    static let liveValue: any ImageCacheClientProtocol = ImageCacheClient()
    static let testValue: any ImageCacheClientProtocol = TestImageCacheClient()
}

private actor TestImageCacheClient: ImageCacheClientProtocol {
    func preload(paths: [String?]) async {}
}

extension DependencyValues {
    var imageCacheClient: any ImageCacheClientProtocol {
        get { self[ImageCacheClientKey.self] }
        set { self[ImageCacheClientKey.self] = newValue }
    }
}
