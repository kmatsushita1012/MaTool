//
//  APIClient.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/19.
//

import Foundation
import Dependencies

//MARK: - Dependencies
enum APIClientKey: DependencyKey {
    static let liveValue: any APIClientProtocol = {
        @Dependency(\.values.apiBaseUrl) var apiBaseUrl
        return APIClient.withDefaultTimeout(
            base: apiBaseUrl
        )
    }()
}

extension DependencyValues {
    var apiClient: any APIClientProtocol {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

// MARK: - APIClientProtocol
protocol APIClientProtocol: Sendable {
    func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        query: [String: Any],
        body: Body?,
        accessToken: String?,
        isCache: Bool
    ) async -> Result<Response, APIError>

    func request<Response: Decodable>(
        path: String,
        method: String,
        query: [String: Any],
        accessToken: String?,
        isCache: Bool
    ) async -> Result<Response, APIError>

    func get<Response: Decodable>(
        path: String,
        query: [String: Any],
        accessToken: String?,
        isCache: Bool
    ) async -> Result<Response, APIError>

    func post<Response: Decodable, Body: Encodable>(
        path: String,
        body: Body,
        query: [String: Any],
        accessToken: String?
    ) async -> Result<Response, APIError>

    func put<Response: Decodable, Body: Encodable>(
        path: String,
        body: Body,
        query: [String: Any],
        accessToken: String?
    ) async -> Result<Response, APIError>

    func delete<Response: Decodable>(
        path: String,
        query: [String: Any],
        accessToken: String?
    ) async -> Result<Response, APIError>
}

// MARK: - APIClient
actor APIClient: APIClientProtocol {
    private let base: String
    private let session: URLSession
    private let cache = NSCache<NSString, NSData>()
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    private struct EmptyBody: Encodable {}

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
    ) async -> Result<Response, APIError> {
        do {
            let url = try makeURL(path: path, query: query)

            // Encode body (early return on failure)
            let bodyDataResult: Result<Data?, APIError> = encodeBody(body)
            if case .failure(let err) = bodyDataResult { return .failure(err) }
            let bodyData = try? bodyDataResult.get()

            let key = cacheKey(url: url, method: method, bodyData: bodyData ?? nil)

            // Cache hit
            if isCache, let cached = cache.object(forKey: key) {
                return decodeResponse(from: cached as Data)
            }

            // Build request and execute
            let urlRequest = makeRequest(url: url, method: method, bodyData: bodyData ?? nil, accessToken: accessToken)
            let (data, http): (Data, HTTPURLResponse?)
            do {
                (data, http) = try await execute(request: urlRequest)
            } catch {
                return .failure(APIError(error))
            }

            // If we have HTTP response, check status code
            if let http = http, !(200...299).contains(http.statusCode) {
                let error = decodeAPIError(from: data, httpStatus: http.statusCode)
                return .failure(APIError(error))
            }

            // Success path: cache and decode
            if isCache { cache.setObject(data as NSData, forKey: key) }
            return decodeResponse(from: data)
        } catch {
            return .failure(APIError(error))
        }
    }

    func request<Response: Decodable>(
        path: String,
        method: String = "GET",
        query: [String: Any] = [:],
        accessToken: String? = nil,
        isCache: Bool = false
    ) async -> Result<Response, APIError> {
        await request(path: path, method: method, query: query, body: Optional<EmptyBody>.none, accessToken: accessToken, isCache: isCache)
    }

    func get<Response: Decodable>(path: String, query: [String: Any] = [:], accessToken: String? = nil, isCache: Bool = false) async -> Result<Response, APIError> {
        await request(path: path, method: "GET", query: query, body: Optional<EmptyBody>.none, accessToken: accessToken, isCache: isCache)
    }

    func post<Response: Decodable, Body: Encodable>(path: String, body: Body, query: [String: Any] = [:], accessToken: String? = nil) async -> Result<Response, APIError> {
        let response: Result<Response, APIError> = await request(path: path, method: "POST", query: query, body: body, accessToken: accessToken, isCache: false)
        cache.removeAllObjects()
        return response
    }

    func put<Response: Decodable, Body: Encodable>(path: String, body: Body, query: [String: Any] = [:], accessToken: String? = nil) async -> Result<Response, APIError> {
        let response: Result<Response, APIError> = await request(path: path, method: "PUT", query: query, body: body, accessToken: accessToken, isCache: false)
        cache.removeAllObjects()
        return response
    }

    func delete<Response: Decodable>(path: String, query: [String: Any] = [:], accessToken: String? = nil) async -> Result<Response, APIError> {
        let response: Result<Response, APIError> = await request(path: path, method: "DELETE", query: query, body: Optional<EmptyBody>.none, accessToken: accessToken, isCache: false)
        cache.removeAllObjects()
        return response
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

    private func encodeBody<Body: Encodable>(_ body: Body?) -> Result<Data?, APIError> {
        guard let body else { return .success(nil) }
        do { return .success(try jsonEncoder.encode(body)) }
        catch { return .failure(APIError(error)) }
    }

    private func decodeResponse<Response: Decodable>(from data: Data) -> Result<Response, APIError> {
        do { return .success(try jsonDecoder.decode(Response.self, from: data)) }
        catch { return .failure(APIError(error)) }
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

    static func withDefaultTimeout(base: String) -> APIClient {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        return APIClient(base: base, session: URLSession(configuration: config))
    }
}

// MARK: - APIClientProtocol+
extension APIClientProtocol {
    // デフォルト値付き request
    func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        query: [String: Any] = [:],
        body: Body? = nil,
        accessToken: String? = nil,
        isCache: Bool = true
    ) async -> Result<Response, APIError> {
        await self.request(
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
    ) async -> Result<Response, APIError> {
        await self.request(
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
    ) async -> Result<Response, APIError> {
        await self.get(
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
    ) async -> Result<Response, APIError> {
        await self.post(
            path: path,
            body: body,
            query: query,
            accessToken: accessToken
        )
    }

    func put<Response: Decodable, Body: Encodable>(
        path: String,
        body: Body,
        query: [String: Any] = [:],
        accessToken: String? = nil
    ) async -> Result<Response, APIError> {
        await self.put(
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
    ) async -> Result<Response, APIError> {
        await self.delete(
            path: path,
            query: query,
            accessToken: accessToken
        )
    }
}

