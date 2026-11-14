import Dependencies
import Foundation
import Kingfisher

protocol ImageCacheClientProtocol: Sendable {
    func preload(paths: [String?]) async
    func preload(path: String) async throws
}

actor ImageCacheClient: ImageCacheClientProtocol {
    private let retrieve: @Sendable (URL) async throws -> Void

    init(retrieve: @escaping @Sendable (URL) async throws -> Void = { url in
        _ = try await KingfisherManager.shared.retrieveImage(
            with: url,
            options: [.cacheOriginalImage]
        )
    }) {
        self.retrieve = retrieve
    }

    func preload(paths: [String?]) async {
        var loadedURLs = Set<URL>()
        for url in paths.compactMap({ Self.url(from: $0) }) where loadedURLs.insert(url).inserted {
            try? await retrieve(url)
        }
    }

    func preload(path: String) async throws {
        guard let url = URL(string: path),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            throw ImageCacheClientError.invalidURL
        }
        try await retrieve(url)
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

enum ImageCacheClientError: Error, Equatable, Sendable {
    case invalidURL
}

enum ImageCacheClientKey: DependencyKey {
    static let liveValue: any ImageCacheClientProtocol = ImageCacheClient()
}

extension DependencyValues {
    var imageCacheClient: any ImageCacheClientProtocol {
        get { self[ImageCacheClientKey.self] }
        set { self[ImageCacheClientKey.self] = newValue }
    }
}
