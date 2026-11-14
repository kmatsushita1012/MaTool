import Foundation
import Testing
@testable import iOSApp

@Suite(.serialized)
struct HTTPClientTests {
    private struct Payload: Codable, Equatable {
        let value: String
    }

    private struct DatePayload: Codable, Equatable {
        let timestamp: Date
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

    @Test("APIのDateはUnix秒で送受信する")
    func dateをUnix秒で送受信する() async throws {
        let (client, _) = makeClient()
        let expected = Date(timeIntervalSince1970: 1_700_000_000)

        let received: DatePayload = try await client.get(path: "/locations")
        let echoed: DatePayload = try await client.put(path: "/locations", body: DatePayload(timestamp: expected))

        #expect(received.timestamp == expected)
        #expect(echoed.timestamp == expected)
        let body = try #require(CacheTestURLProtocol.recordedRequestBodies().last ?? nil)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Double])
        #expect(object["timestamp"] == expected.timeIntervalSince1970)
    }


    @Test("GETのクエリは文字列・整数・小数・BoolだけをURLにシリアライズする")
    func queryParametersAreEncodedBySupportedType() async throws {
        let (client, _) = makeClient()
        let _: Payload = try await client.get(path: "/routes", query: [
            "name": "町名", "count": 3, "ratio": 1.5,
            "enabled": true, "ignored": ["unhandled"]
        ])

        let request = try #require(CacheTestURLProtocol.recordedRequests().first)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map {
            ($0.name, $0.value ?? "")
        })
        #expect(items["name"] == "町名")
        #expect(items["count"] == "3")
        #expect(items["ratio"] == "1.5")
        #expect(items["enabled"] == "true")
        #expect(items["ignored"] == nil)
    }

    @Test("POSTとDELETEは適切なHTTPメソッドを送信し、リクエスト本文を必要時だけ設定する")
    func postAndDeleteUseExpectedRequests() async throws {
        let (client, _) = makeClient()
        let posted: Payload = try await client.post(path: "/items", body: Payload(value: "submitted"))
        let deleted: Payload = try await client.delete(path: "/items")
        try await client.delete(path: "/items")

        #expect(posted.value == "guest")
        #expect(deleted.value == "guest")
        let requests = CacheTestURLProtocol.recordedRequests()
        #expect(requests.map(\.httpMethod) == ["POST", "DELETE", "DELETE"])
        #expect(requests[0].value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try #require(CacheTestURLProtocol.recordedRequestBodies().first ?? nil)
        let decoded = try JSONDecoder().decode(Payload.self, from: body)
        #expect(decoded == Payload(value: "submitted"))
        #expect(requests[1].httpBody == nil)
    }

    @Test("サーバーがエラー応答を返したときにHTTPステータスと公開メッセージを失わない")
    func serverErrorReportsStatusAndMessage() async throws {
        let (client, _) = makeClient()
        do {
            let _: Payload = try await client.get(path: "/server-error")
            Issue.record("5xx response must fail")
        } catch let error as AppError {
            #expect(error == .be(.server(statusCode: 503, message: "サーバーに接続できません")))
            #expect(error.message.contains("サーバーに接続できません"))
        }
    }

    @Test("受信JSONのパース失敗は復号エラーとして呼び出し元に返す")
    func invalidJSONReportsDecodingError() async {
        let (client, _) = makeClient()
        await #expect(throws: Error.self) {
            let _: Payload = try await client.get(path: "/bad-json")
        }
    }

    @Test("URLSession自体が失敗した場合はユーザー向けの接続エラーに変換する")
    func transportErrorsHaveConnectionMessage() async {
        let (client, _) = makeClient()
        do {
            let _: Payload = try await client.get(path: "/transport-error")
            Issue.record("Network failure must not succeed")
        } catch let error as AppError {
            #expect(error.message.contains("インターネット接続"))
        } catch {
            Issue.record("Transport error was not normalized to AppError")
        }
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
    private static var requestBodies: [Data?] = []

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        requests = []
        requestBodies = []
    }

    static func recordedRequests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    static func recordedRequestBodies() -> [Data?] {
        lock.lock()
        defer { lock.unlock() }
        return requestBodies
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "cache-regression.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = Self.bodyData(from: request)
        Self.lock.lock()
        Self.requests.append(request)
        Self.requestBodies.append(body)
        Self.lock.unlock()

        if request.url?.path == "/transport-error" {
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
            return
        }
        let data: Data
        if request.url?.path == "/server-error" {
            data = Data("{\"message\":\"internal\",\"localizedDescription\":\"サーバーに接続できません\"}".utf8)
        } else if request.url?.path == "/bad-json" {
            data = Data("not-json".utf8)
        } else if request.url?.path == "/locations" {
            data = Data("{\"timestamp\":1700000000}".utf8)
        } else {
            let value = request.value(forHTTPHeaderField: "Authorization") == nil ? "guest" : "signed-in"
            data = Data("{\"value\":\"\(value)\"}".utf8)
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: request.url?.path == "/server-error" ? 503 : 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Cache-Control": "public, max-age=3600"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func bodyData(from request: URLRequest) -> Data? {
        if let httpBody = request.httpBody { return httpBody }
        guard let stream = request.httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
        defer { buffer.deallocate() }
        var data = Data()
        while true {
            let count = stream.read(buffer, maxLength: 1024)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
