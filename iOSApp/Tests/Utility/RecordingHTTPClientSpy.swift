import Foundation
@testable import iOSApp

/// HTTPClientProtocol の境界でリクエスト内容と結果を検証するためのSpy。
/// 実ネットワーク通信を一切行わない。
actor RecordingHTTPClientSpy: HTTPClientProtocol {
    struct Call: Equatable, Sendable {
        let method: String
        let path: String
        let query: [String: String]
        let accessToken: String?
        let isCache: Bool
        let body: Data?
    }

    enum Failure: Swift.Error, Equatable {
        case requested
    }

    private let responseData: Data
    private let shouldFail: Bool
    private var recorded: [Call] = []

    init<Response: Encodable>(response: Response, shouldFail: Bool = false) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        responseData = try encoder.encode(response)
        self.shouldFail = shouldFail
    }

    init(responseJSON: String, shouldFail: Bool = false) {
        responseData = Data(responseJSON.utf8)
        self.shouldFail = shouldFail
    }

    func calls() -> [Call] {
        recorded
    }

    private func record(
        method: String, path: String, query: [String: Any],
        accessToken: String?, isCache: Bool, body: Data?
    ) {
        recorded.append(Call(
            method: method, path: path,
            query: query.mapValues { String(describing: $0) },
            accessToken: accessToken, isCache: isCache,
            body: body
        ))
    }

    private func response<Response: Decodable>() throws -> Response {
        if shouldFail { throw Failure.requested }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(Response.self, from: responseData)
    }

    func request<Response: Decodable, Body: Encodable>(
        path: String, method: String, query: [String: Any], body: Body?,
        accessToken: String?, isCache: Bool
    ) async throws -> Response {
        let encodedBody: Data?
        if let body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            encodedBody = try encoder.encode(body)
        } else {
            encodedBody = nil
        }
        record(method: method, path: path, query: query,
               accessToken: accessToken, isCache: isCache, body: encodedBody)
        return try response()
    }

    func request<Response: Decodable>(
        path: String, method: String, query: [String: Any],
        accessToken: String?, isCache: Bool
    ) async throws -> Response {
        record(method: method, path: path, query: query,
               accessToken: accessToken, isCache: isCache, body: nil)
        return try response()
    }

    func get<Response: Decodable>(
        path: String, query: [String: Any], accessToken: String?, isCache: Bool
    ) async throws -> Response {
        record(method: "GET", path: path, query: query,
               accessToken: accessToken, isCache: isCache, body: nil)
        return try response()
    }

    func post<Response: Decodable, Body: Encodable>(
        path: String, body: Body, query: [String: Any], accessToken: String?
    ) async throws -> Response {
        let encoded = try encode(body)
        record(method: "POST", path: path, query: query,
               accessToken: accessToken, isCache: false, body: encoded)
        return try response()
    }

    func put<Response: Decodable, Body: Encodable>(
        path: String, body: Body, query: [String: Any], accessToken: String?
    ) async throws -> Response {
        let encoded = try encode(body)
        record(method: "PUT", path: path, query: query,
               accessToken: accessToken, isCache: false, body: encoded)
        return try response()
    }

    func delete<Response: Decodable>(
        path: String, query: [String: Any], accessToken: String?
    ) async throws -> Response {
        record(method: "DELETE", path: path, query: query,
               accessToken: accessToken, isCache: false, body: nil)
        return try response()
    }

    func delete(path: String, query: [String: Any], accessToken: String?) async throws {
        record(method: "DELETE", path: path, query: query,
               accessToken: accessToken, isCache: false, body: nil)
        if shouldFail { throw Failure.requested }
    }

    private func encode<Body: Encodable>(_ body: Body) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(body)
    }
}
