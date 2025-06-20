//
//  NetworkManager.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    
    let session: URLSession
    
    private init() {
        // キャッシュディレクトリの設定
        let cacheSizeMemory = 512 * 1024 * 1024 // 512MB
        let cacheSizeDisk = 512 * 1024 * 1024 // 512MB
        let cache = URLCache(memoryCapacity: cacheSizeMemory, diskCapacity: cacheSizeDisk, diskPath: "myCache")
        
        // URLSessionConfigurationの設定
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        configuration.requestCachePolicy = .useProtocolCachePolicy
        
        // URLSessionの作成
        self.session = URLSession(configuration: configuration)
    }
}

func executeURLSession(request:URLRequest) async -> Result<Data,Error> {
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode){
            print("Success \(String(describing: request.httpMethod))  \(String(describing: response.url?.absoluteString))")
            return .success(data)
        } else {
            print("failure \(String(describing: request.httpMethod)) \(String(describing: response.url?.absoluteString)) \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
            return .failure(NSError(domain: "HTTP Error", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: nil))
        }
    } catch {
        print("failure  \(String(describing: request.httpMethod)) \(String(describing: request.url?.absoluteString)) \(error)\n")
        return .failure(error)
    }
}

func makeURL(_ base: String, _ path: String, _ query: [String: Any]? = nil) throws -> URL{
    guard var urlComponents = URLComponents(string: base + path) else {
        throw NSError(domain: "Invalid base URL or path", code: -1, userInfo: nil)
    }
    // クエリパラメータを設定
    if let query = query {
        urlComponents.queryItems = query.compactMap { key, value in
            if let stringValue = value as? String {
                return URLQueryItem(name: key, value: stringValue)
            } else if let intValue = value as? Int {
                return URLQueryItem(name: key, value: String(intValue))
            } else if let doubleValue = value as? Double {
                return URLQueryItem(name: key, value: String(doubleValue))
            } else if let boolValue = value as? Bool {
                return URLQueryItem(name: key, value: boolValue ? "true" : "false")
            } else {
                return nil // サポートされていない型は無視
            }
        }
    }
    // URLを構築
    guard let url = urlComponents.url else {
        throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
    }
    return url
}

func makeRequest(_ url: URL, _ method: String, body: Data? = nil, accessToken: String? = nil) -> URLRequest{
    var request = URLRequest(url: url)
    request.httpMethod = method
    if let accessToken = accessToken{
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
    if let body = body {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
    }
    return request
}

func performGetRequest(
    base: String,
    path: String,
    query: [String: Any] = [:],
    accessToken: String? = nil
) async -> Result<Data, Error> {
    let urlResult = Result { try makeURL(base, path, query) }
    guard case .success(let url) = urlResult else {
        return urlResult.map { _ in Data() }
    }
    let request = makeRequest(url, "GET", accessToken: accessToken)
    return await executeURLSession(request: request)
}

func performPostRequest(
    base: String,
    path: String,
    query: [String: Any] = [:],
    body: Data,
    accessToken: String? = nil
) async -> Result<Data, Error> {
    let urlResult = Result { try makeURL(base, path, query) }
    guard case .success(let url) = urlResult else {
        return urlResult.map { _ in Data() }
    }
    let request = makeRequest(url, "POST", body: body, accessToken: accessToken)
    return await executeURLSession(request: request)
}

func performPutRequest(
    base: String,
    path: String,
    query: [String: Any] = [:],
    body: Data,
    accessToken: String? = nil
) async -> Result<Data, Error> {
    let urlResult = Result { try makeURL(base, path, query) }
    guard case .success(let url) = urlResult else {
        return urlResult.map { _ in Data() }
    }
    let request = makeRequest(url, "PUT", body: body, accessToken: accessToken)
    return await executeURLSession(request: request)
}

func performDeleteRequest(
    base: String,
    path: String,
    query: [String: Any] = [:],
    accessToken: String? = nil
) async -> Result<Data, Error> {
    let urlResult = Result { try makeURL(base, path, query) }
    guard case .success(let url) = urlResult else {
        return urlResult.map { _ in Data() }
    }
    let request = makeRequest(url, "DELETE", accessToken: accessToken)
    return await executeURLSession(request: request)
}

//TODO
extension ApiError {
    static func factory(_ error: Error)->Self{
        return Self.unknown(error.localizedDescription)
    }
}
