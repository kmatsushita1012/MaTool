import Testing
@testable import iOSApp

struct ImageCacheClientTests {
    @Test("広告画像として扱えないURLをプリロードしない")
    func rejectsNonHTTPImageURL() async {
        await #expect(throws: ImageCacheClientError.invalidURL) {
            try await ImageCacheClient().preload(path: "file:///tmp/banner.jpg")
        }
    }
}
