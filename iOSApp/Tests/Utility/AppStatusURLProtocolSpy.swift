import Foundation

/// URL queryに応答を埋め込み、グローバルな共有状態を持たずにHTTPを模擬する。
final class AppStatusURLProtocolSpy: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "app-status.invalid"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let items = components.queryItems ?? []
        let raw = items.first(where: { $0.name == "data" })?.value ?? ""
        let status = Int(items.first(where: { $0.name == "status" })?.value ?? "200") ?? 200
        guard let response = HTTPURLResponse(
            url: url, statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let data = Data(base64Encoded: raw) ?? Data()
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func makeURL(json: String, status: Int = 200) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "app-status.invalid"
        components.path = "/config.json"
        components.queryItems = [
            URLQueryItem(name: "data", value: Data(json.utf8).base64EncodedString()),
            URLQueryItem(name: "status", value: String(status))
        ]
        return components.url!
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppStatusURLProtocolSpy.self]
        return URLSession(configuration: configuration)
    }
}
