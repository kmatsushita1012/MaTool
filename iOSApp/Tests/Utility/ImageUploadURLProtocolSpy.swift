import Foundation

final class ImageUploadURLProtocolSpy: URLProtocol {
    private static let state = State()

    static func configure(statusCode: Int) { state.configure(statusCode: statusCode) }
    static var lastRequest: URLRequest? { state.lastRequest }
    static var lastBody: Data? { state.lastBody }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let body = request.httpBody ?? readBody(from: request.httpBodyStream)
        let statusCode = Self.state.record(request, body: body)
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        ) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private func readBody(from stream: InputStream?) -> Data? {
        guard let stream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let count = buffer.withUnsafeMutableBufferPointer { pointer in
                stream.read(pointer.baseAddress!, maxLength: pointer.count)
            }
            guard count > 0 else { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }

    private final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var statusCode = 204
        private var request: URLRequest?
        private var body: Data?

        var lastRequest: URLRequest? { lock.withLock { request } }
        var lastBody: Data? { lock.withLock { body } }

        func configure(statusCode: Int) {
            lock.withLock { self.statusCode = statusCode }
        }

        func record(_ request: URLRequest, body: Data?) -> Int {
            lock.withLock {
                self.request = request
                self.body = body
                return statusCode
            }
        }
    }
}
