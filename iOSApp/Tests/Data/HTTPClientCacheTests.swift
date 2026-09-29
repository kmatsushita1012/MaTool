import Foundation
import Testing
@testable import iOSApp

@Suite(.serialized)
struct HTTPClientCacheTests {
    private struct Payload: Codable, Equatable {
        let value: String
    }

    @Test("同じURLでもログイン後は未ログイン応答を再利用しない")
    func ログイン後は再取得する() async throws {
        let (client, _) = makeClient()
        let api: any HTTPClientProtocol = client

        let guest: Payload = try await api.get(path: "/routes/route-1")
        let signedIn: Payload = try await api.get(path: "/routes/route-1", accessToken: "token")

        #expect(guest.value == "guest")
        #expect(signedIn.value == "signed-in")
        let requests = CacheTestURLProtocol.recordedRequests()
        #expect(requests.count == 2)
        let guestRequest = try #require(requests.first)
        let signedInRequest = try #require(requests.last)
        #expect(guestRequest.cachePolicy == .useProtocolCachePolicy)
        #expect(signedInRequest.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(signedInRequest.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(signedInRequest.value(forHTTPHeaderField: "Cache-Control") == "no-cache, no-store")
    }

    @Test("キャッシュ無効指定は再検証と保存禁止を要求する")
    func キャッシュ無効指定() async throws {
        let (client, _) = makeClient()

        let response: Payload = try await client.get(path: "/routes/route-1", isCache: false)

        #expect(response.value == "guest")
        let request = try #require(CacheTestURLProtocol.recordedRequests().first)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.value(forHTTPHeaderField: "Cache-Control") == "no-cache, no-store")
    }

    @Test("更新成功後は既存キャッシュを無効化する")
    func 更新後の無効化() async throws {
        let (client, cache) = makeClient()
        let url = try #require(URL(string: "https://cache-regression.test/routes/route-1"))
        let cachedRequest = URLRequest(url: url)
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Cache-Control": "public, max-age=3600"]
        ))
        cache.storeCachedResponse(CachedURLResponse(response: response, data: Data("{}".utf8)), for: cachedRequest)
        #expect(cache.cachedResponse(for: cachedRequest) != nil)

        let _: Payload = try await client.put(path: "/routes/route-1", body: Payload(value: "updated"))

        #expect(cache.cachedResponse(for: cachedRequest) == nil)
    }

    private func makeClient() -> (HTTPClient, URLCache) {
        CacheTestURLProtocol.reset()
        let cache = URLCache(memoryCapacity: 1024 * 1024, diskCapacity: 0)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = cache
        configuration.protocolClasses = [CacheTestURLProtocol.self]
        return (HTTPClient(base: "https://cache-regression.test", session: URLSession(configuration: configuration)), cache)
    }
}

private final class CacheTestURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var requests: [URLRequest] = []

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        requests = []
    }

    static func recordedRequests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "cache-regression.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        Self.lock.unlock()

        let value = request.value(forHTTPHeaderField: "Authorization") == nil ? "guest" : "signed-in"
        let data = Data("{\"value\":\"\(value)\"}".utf8)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Cache-Control": "public, max-age=3600"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
