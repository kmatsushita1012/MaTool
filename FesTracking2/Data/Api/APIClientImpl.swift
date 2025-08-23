//
//  APIClientImpl.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/08/19.
//

import Foundation

struct APIClient: APIClientProtocol {

    private let base: String
    private let session: URLSession
    private let cache = NSCache<NSString, NSData>()

    init(base: String, session: URLSession = .shared) {
        self.base = base
        self.session = session
    }

    func request(
        path: String,
        method: String = "GET",
        query: [String: Any] = [:],
        body: Data? = nil,
        accessToken: String? = nil,
        isCache: Bool = false
    ) async -> Result<Data, APIError> {
        do {
            let url = try makeURL(path: path, query: query)

            if isCache, let cached = cache.object(forKey: url.absoluteString as NSString) {
                print("Cache Hit")
                return .success(cached as Data)
            }

            let request = makeRequest(url: url, method: method, body: body, accessToken: accessToken)
            let result = await execute(request: request)

            switch result {
            case .success(let data):
                if isCache {
                    cache.setObject(data as NSData, forKey: url.absoluteString as NSString)
                }
                return .success(data)
            case .failure(let error):
                return .failure(APIError(error))
            }
        } catch {
            return .failure(APIError(error))
        }
    }

    func get(path: String, query: [String: Any] = [:], accessToken: String? = nil, isCache: Bool = false) async -> Result<Data, APIError> {
        await request(path: path, method: "GET", query: query, accessToken: accessToken, isCache: isCache)
    }

    func post(path: String, body: Data, query: [String: Any] = [:], accessToken: String? = nil) async -> Result<Data, APIError> {
        let responce = await request(path: path, method: "POST", query: query, body: body, accessToken: accessToken)
        cache.removeAllObjects()
        return responce
    }


    func put(path: String, body: Data, query: [String: Any] = [:], accessToken: String? = nil) async -> Result<Data, APIError> {
        let responce = await request(path: path, method: "PUT", query: query, body: body, accessToken: accessToken)
        cache.removeAllObjects()
        return responce
    }

    func delete(path: String, query: [String: Any] = [:], accessToken: String? = nil) async -> Result<Data, APIError> {
        let responce = await request(path: path, method: "DELETE", query: query, accessToken: accessToken)
        cache.removeAllObjects()
        return responce
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

    private func makeRequest(url: URL, method: String, body: Data? = nil, accessToken: String?) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }

    private func execute(request: URLRequest) async -> Result<Data, Error> {
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    return .success(data)
                } else {
                    return .failure(NSError(domain: "HTTP Error", code: http.statusCode))
                }
            }
            return .success(data)
        } catch {
            return .failure(error)
        }
    }
}
