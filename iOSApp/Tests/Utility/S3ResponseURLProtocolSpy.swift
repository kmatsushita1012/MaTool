import Foundation

/// S3 upload checks only, no global state or external connection.
final class S3ResponseURLProtocolSpy: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "image-upload.invalid"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        switch url.lastPathComponent {
        case "offline":
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        case "non-http":
            let response = URLResponse(
                url: url,
                mimeType: "application/octet-stream",
                expectedContentLength: 0,
                textEncodingName: nil
            )
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        default:
            let statusCode = Int(url.lastPathComponent) ?? 500
            guard let response = HTTPURLResponse(
                url: url, statusCode: statusCode, httpVersion: "HTTP/1.1",
                headerFields: nil
            ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [S3ResponseURLProtocolSpy.self]
        return URLSession(configuration: configuration)
    }
}
