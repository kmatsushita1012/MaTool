import Dependencies

public protocol HTTPClientProtocol: Sendable {
    func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        query: [String: Any],
        body: Body?,
        accessToken: String?,
        isCache: Bool
    ) async throws -> Response

    func request<Response: Decodable>(
        path: String,
        method: String,
        query: [String: Any],
        accessToken: String?,
        isCache: Bool
    ) async throws -> Response

    func get<Response: Decodable>(
        path: String,
        query: [String: Any],
        accessToken: String?,
        isCache: Bool
    ) async throws -> Response

    func post<Response: Decodable, Body: Encodable>(
        path: String,
        body: Body,
        query: [String: Any],
        accessToken: String?
    ) async throws -> Response

    func put<Response: Decodable, Body: Encodable>(
        path: String,
        body: Body,
        query: [String: Any],
        accessToken: String?
    ) async throws -> Response

    func delete<Response: Decodable>(
        path: String,
        query: [String: Any],
        accessToken: String?
    ) async throws -> Response

    func delete(
        path: String,
        query: [String: Any],
        accessToken: String?
    ) async throws
}

public enum HTTPClientKey: DependencyKey {
    public static let liveValue: any HTTPClientProtocol = DependencyConfiguration.missing("HTTPClient")
}

public extension DependencyValues {
    var httpClient: any HTTPClientProtocol {
        get { self[HTTPClientKey.self] }
        set { self[HTTPClientKey.self] = newValue }
    }
}

public extension HTTPClientProtocol {
    func request<Response: Decodable, Body: Encodable>(path: String, method: String, query: [String: Any] = [:], body: Body? = nil, accessToken: String? = nil, isCache: Bool = true) async throws -> Response {
        try await request(path: path, method: method, query: query, body: body, accessToken: accessToken, isCache: isCache)
    }

    func request<Response: Decodable>(path: String, method: String, query: [String: Any] = [:], accessToken: String? = nil, isCache: Bool = true) async throws -> Response {
        try await request(path: path, method: method, query: query, accessToken: accessToken, isCache: isCache)
    }

    func get<Response: Decodable>(path: String, query: [String: Any] = [:], accessToken: String? = nil, isCache: Bool = true) async throws -> Response {
        try await get(path: path, query: query, accessToken: accessToken, isCache: isCache)
    }

    func post<Response: Decodable, Body: Encodable>(path: String, body: Body, query: [String: Any] = [:], accessToken: String? = nil) async throws -> Response {
        try await post(path: path, body: body, query: query, accessToken: accessToken)
    }

    func put<Response: Decodable, Body: Encodable>(path: String, body: Body, query: [String: Any] = [:], accessToken: String? = nil) async throws -> Response {
        try await put(path: path, body: body, query: query, accessToken: accessToken)
    }

    func delete<Response: Decodable>(path: String, query: [String: Any] = [:], accessToken: String? = nil) async throws -> Response {
        try await delete(path: path, query: query, accessToken: accessToken)
    }

    func delete(path: String, query: [String: Any] = [:], accessToken: String? = nil) async throws {
        try await delete(path: path, query: query, accessToken: accessToken)
    }
}
