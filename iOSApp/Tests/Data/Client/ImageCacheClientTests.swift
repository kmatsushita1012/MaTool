import Foundation
import Testing
@testable import iOSApp

struct ImageCacheClientTests {
    @Test("有効なURLのみを重複排除して順番に取得する")
    func preloadsDistinctValidURLs() async {
        let recorder = ImageRetrievalRecorder()
        let client = ImageCacheClient { url in
            await recorder.record(url)
        }

        await client.preload(paths: [
            nil, "", "relative/image.jpg", "https://example.com/a.jpg",
            "https://example.com/a.jpg", "https://example.com/b.jpg"
        ])

        #expect(await recorder.paths() == [
            "https://example.com/a.jpg", "https://example.com/b.jpg"
        ])
    }

    @Test("画像取得失敗後も次のURLを処理する")
    func continuesAfterRetrievalFailure() async {
        let recorder = ImageRetrievalRecorder()
        let client = ImageCacheClient { url in
            await recorder.record(url)
            if url.lastPathComponent == "fail.jpg" {
                throw ImageRetrievalFailure.requested
            }
        }

        await client.preload(paths: [
            "https://example.com/fail.jpg",
            "https://example.com/success.jpg"
        ])

        #expect(await recorder.paths() == [
            "https://example.com/fail.jpg",
            "https://example.com/success.jpg"
        ])
    }

    @Test("URLが空の場合は画像取得処理を一切実行しない")
    func skipsInvalidPaths() async {
        let recorder = ImageRetrievalRecorder()
        let client = ImageCacheClient { url in await recorder.record(url) }
        await client.preload(paths: [nil, "", "image.png", "relative/path"])
        #expect(await recorder.paths().isEmpty)
    }
}

private enum ImageRetrievalFailure: Error {
    case requested
}

private actor ImageRetrievalRecorder {
    private var urls: [URL] = []
    func record(_ url: URL) { urls.append(url) }
    func paths() -> [String] { urls.map(\.absoluteString) }
}
