//
//  HTTPClient.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/19.
//

import Foundation
import Dependencies

//MARK: - Dependencies
enum HTTPClientKey: DependencyKey {
    static let liveValue: any HTTPClientProtocol = {
        @Dependency(\.values.apiBaseUrl) var apiBaseUrl
        return HTTPClient.withDefaultTimeout(
            base: apiBaseUrl
        )
    }()
}

extension DependencyValues {
    var httpClient: any HTTPClientProtocol {
        get { self[HTTPClientKey.self] }
        set { self[HTTPClientKey.self] = newValue }
    }
}

// MARK: - APIClientProtocol
protocol HTTPClientProtocol: Sendable {
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

// MARK: - APIClient
actor HTTPClient: HTTPClientProtocol {
    private let base: String
    private let session: URLSession
    private let cache = NSCache<NSString, NSData>()
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    private struct EmptyBody: Encodable {}
    private struct EmptyResponse: Decodable {}

    init(base: String, session: URLSession = .shared) {
        self.base = base
        self.session = session
        self.jsonEncoder = JSONEncoder()
        self.jsonDecoder = JSONDecoder()
    }

    init(base: String, timeoutIntervalForRequest: TimeInterval = 10, timeoutIntervalForResource: TimeInterval = 30) {
        self.base = base
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutIntervalForRequest
        config.timeoutIntervalForResource = timeoutIntervalForResource
        self.session = URLSession(configuration: config)
        self.jsonEncoder = JSONEncoder()
        self.jsonDecoder = JSONDecoder()
    }

    private struct ErrorResponse: Decodable {
        let message: String
        let localizedDescription: String?
    }

    func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String = "GET",
        query: [String: Any] = [:],
        body: Body? = nil,
        accessToken: String? = nil,
        isCache: Bool = false
    ) async throws -> Response {
        do {
            let url = try makeURL(path: path, query: query)

            let bodyData = try encodeBody(body)

            let key = cacheKey(url: url, method: method, bodyData: bodyData ?? nil)

            // Cache hit
            if isCache, let cached = cache.object(forKey: key) {
                return try decodeResponse(from: cached as Data)
            }

            // Build request and execute
            let urlRequest = makeRequest(url: url, method: method, bodyData: bodyData ?? nil, accessToken: accessToken)
            let (data, http): (Data, HTTPURLResponse?)
            do {
                (data, http) = try await execute(request: urlRequest)
            } catch {
                throw APIError(error)
            }

            // If we have HTTP response, check status code
            if let http = http, !(200...299).contains(http.statusCode) {
                let error = decodeAPIError(from: data, httpStatus: http.statusCode)
                throw APIError(error)
            }

            // Success path: cache and decode
            if isCache { cache.setObject(data as NSData, forKey: key) }
            return try decodeResponse(from: data)
        } catch {
            throw APIError(error)
        }
    }

    func request<Response: Decodable>(
        path: String,
        method: String = "GET",
        query: [String: Any] = [:],
        accessToken: String? = nil,
        isCache: Bool = false
    ) async throws -> Response {
        try await request(path: path, method: method, query: query, body: Optional<EmptyBody>.none, accessToken: accessToken, isCache: isCache)
    }

    func get<Response: Decodable>(path: String, query: [String: Any] = [:], accessToken: String? = nil, isCache: Bool = false) async throws -> Response {
        try await request(path: path, method: "GET", query: query, body: Optional<EmptyBody>.none, accessToken: accessToken, isCache: isCache)
    }

    func post<Response: Decodable, Body: Encodable>(path: String, body: Body, query: [String: Any] = [:], accessToken: String? = nil) async throws -> Response {
        let response: Response = try await request(path: path, method: "POST", query: query, body: body, accessToken: accessToken, isCache: false)
        cache.removeAllObjects()
        return response
    }

    func put<Response: Decodable, Body: Encodable>(path: String, body: Body, query: [String: Any] = [:], accessToken: String? = nil) async throws -> Response {
        let response: Response = try await request(path: path, method: "PUT", query: query, body: body, accessToken: accessToken, isCache: false)
        cache.removeAllObjects()
        return response
    }

    func delete<Response: Decodable>(path: String, query: [String: Any] = [:], accessToken: String? = nil) async throws -> Response {
        let response: Response = try await request(path: path, method: "DELETE", query: query, body: Optional<EmptyBody>.none, accessToken: accessToken, isCache: false)
        cache.removeAllObjects()
        return response
    }

    func delete(path: String, query: [String: Any] = [:], accessToken: String? = nil) async throws {
        let _: EmptyResponse = try await request(
            path: path,
            method: "DELETE",
            query: query,
            body: Optional<EmptyBody>.none,
            accessToken: accessToken,
            isCache: false
        )
        cache.removeAllObjects()
    }

    private func makeURL(path: String, query: [String: Any]) throws -> URL {
        guard var components = URLComponents(string: base + path) else {
            throw NSError(domain: "Invalid URL", code: -1)
        }
        if !query.isEmpty {
            components.queryItems = query.compactMap { key, value in
                switch value {
                case let v as String: return URLQueryItem(name: key, value: v)
                case let v as Int: return URLQueryItem(name: key, value: String(v))
                case let v as Double: return URLQueryItem(name: key, value: String(v))
                case let v as Bool: return URLQueryItem(name: key, value: v ? "true" : "false")
                default: return nil
                }
            }
        }
        guard let url = components.url else {
            throw NSError(domain: "Invalid URL", code: -1)
        }
        return url
    }

    private func makeRequest(url: URL, method: String, bodyData: Data? = nil, accessToken: String?) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let bodyData = bodyData {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
        }
        return request
    }

    private func encodeBody<Body: Encodable>(_ body: Body?) throws -> Data? {
        guard let body else { return nil }
        return try jsonEncoder.encode(body)
    }

    private func decodeResponse<Response: Decodable>(from data: Data) throws -> Response {
        try jsonDecoder.decode(Response.self, from: data)
    }

    private func execute(request: URLRequest) async throws -> (Data, HTTPURLResponse?) {
        let (data, response) = try await session.data(for: request)
        return (data, response as? HTTPURLResponse)
    }

    private func decodeAPIError(from data: Data, httpStatus: Int) -> Error {
        if !data.isEmpty, let decoded = try? jsonDecoder.decode(ErrorResponse.self, from: data) {
            let description = decoded.localizedDescription ?? decoded.message
            return NSError(domain: "HTTP Error", code: httpStatus, userInfo: [NSLocalizedDescriptionKey: description])
        }
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return NSError(domain: "HTTP Error", code: httpStatus, userInfo: [NSLocalizedDescriptionKey: text])
        }
        return NSError(domain: "HTTP Error", code: httpStatus, userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(httpStatus)"])
    }

    private func cacheKey(url: URL, method: String, bodyData: Data?) -> NSString {
        if let bodyData = bodyData, !bodyData.isEmpty {
            let hash = String(bodyData.hashValue)
            return "\(method)::\(url.absoluteString)::\(hash)" as NSString
        } else {
            return "\(method)::\(url.absoluteString)" as NSString
        }
    }

    static func withDefaultTimeout(base: String) -> HTTPClient {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        return HTTPClient(base: base, session: URLSession(configuration: config))
    }
}

// MARK: - APIClientProtocol+
extension HTTPClientProtocol {
    // デフォルト値付き request
    func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        query: [String: Any] = [:],
        body: Body? = nil,
        accessToken: String? = nil,
        isCache: Bool = true
    ) async throws -> Response {
        try await self.request(
            path: path,
            method: method,
            query: query,
            body: body,
            accessToken: accessToken,
            isCache: isCache
        )
    }

    func request<Response: Decodable>(
        path: String,
        method: String,
        query: [String: Any] = [:],
        accessToken: String? = nil,
        isCache: Bool = true
    ) async throws -> Response {
        try await self.request(
            path: path,
            method: method,
            query: query,
            accessToken: accessToken,
            isCache: isCache
        )
    }

    func get<Response: Decodable>(
        path: String,
        query: [String: Any] = [:],
        accessToken: String? = nil,
        isCache: Bool = true
    ) async throws -> Response {
        try await self.get(
            path: path,
            query: query,
            accessToken: accessToken,
            isCache: isCache
        )
    }

    func post<Response: Decodable, Body: Encodable>(
        path: String,
        body: Body,
        query: [String: Any] = [:],
        accessToken: String? = nil
    ) async throws -> Response {
        try await self.post(
            path: path,
            body: body,
            query: query,
            accessToken: accessToken
        )
    }

    func delete(
        path: String,
        query: [String: Any] = [:],
        accessToken: String? = nil
    ) async throws {
        try await self.delete(
            path: path,
            query: query,
            accessToken: accessToken
        )
    }

    func put<Response: Decodable, Body: Encodable>(
        path: String,
        body: Body,
        query: [String: Any] = [:],
        accessToken: String? = nil
    ) async throws -> Response {
        try await self.put(
            path: path,
            body: body,
            query: query,
            accessToken: accessToken
        )
    }

    func delete<Response: Decodable>(
        path: String,
        query: [String: Any] = [:],
        accessToken: String? = nil
    ) async throws -> Response {
        try await self.delete(
            path: path,
            query: query,
            accessToken: accessToken
        )
    }
}

@available(*, deprecated, message: "Use async throws APIs instead of Result wrappers.")
extension HTTPClientProtocol {
    func requestResult<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        query: [String: Any] = [:],
        body: Body? = nil,
        accessToken: String? = nil,
        isCache: Bool = true
    ) async -> Result<Response, APIError> {
        do {
            return .success(try await request(path: path, method: method, query: query, body: body, accessToken: accessToken, isCache: isCache))
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.unknown(message: error.localizedDescription))
        }
    }

    func requestResult<Response: Decodable>(
        path: String,
        method: String,
        query: [String: Any] = [:],
        accessToken: String? = nil,
        isCache: Bool = true
    ) async -> Result<Response, APIError> {
        do {
            return .success(try await request(path: path, method: method, query: query, accessToken: accessToken, isCache: isCache))
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.unknown(message: error.localizedDescription))
        }
    }

    func getResult<Response: Decodable>(
        path: String,
        query: [String: Any] = [:],
        accessToken: String? = nil,
        isCache: Bool = true
    ) async -> Result<Response, APIError> {
        do {
            return .success(try await get(path: path, query: query, accessToken: accessToken, isCache: isCache))
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.unknown(message: error.localizedDescription))
        }
    }

    func postResult<Response: Decodable, Body: Encodable>(
        path: String,
        body: Body,
        query: [String: Any] = [:],
        accessToken: String? = nil
    ) async -> Result<Response, APIError> {
        do {
            return .success(try await post(path: path, body: body, query: query, accessToken: accessToken))
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.unknown(message: error.localizedDescription))
        }
    }

    func putResult<Response: Decodable, Body: Encodable>(
        path: String,
        body: Body,
        query: [String: Any] = [:],
        accessToken: String? = nil
    ) async -> Result<Response, APIError> {
        do {
            return .success(try await put(path: path, body: body, query: query, accessToken: accessToken))
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.unknown(message: error.localizedDescription))
        }
    }

    func deleteResult<Response: Decodable>(
        path: String,
        query: [String: Any] = [:],
        accessToken: String? = nil
    ) async -> Result<Response, APIError> {
        do {
            return .success(try await delete(path: path, query: query, accessToken: accessToken))
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.unknown(message: error.localizedDescription))
        }
    }
}
