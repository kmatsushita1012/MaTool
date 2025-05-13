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
        if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
            return .success(data)
        } else {
            return .failure(NSError(domain: "HTTP Error", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: nil))
        }
    } catch {
        return .failure(error)
    }
}

func performGetRequest(path: String, query: [String: Any] = [:], accessToken: String? = nil ) async -> Result<Data, Error> {
    // 環境変数からベースURLを取得（例: "https://example.com"）
    guard var urlComponents = URLComponents(string: "https://example.com" + path) else {
        return .failure(NSError(domain: "Invalid base URL or path", code: -1, userInfo: nil))
    }
    // クエリパラメータを設定
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
    // URLを構築
    guard let url = urlComponents.url else {
        return .failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil))
    }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    if let accessToken = accessToken{
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
    return await executeURLSession(request: request)
}

func performPostRequest(path: String, body: Data, accessToken: String? = nil ) async -> Result<Data, Error> {
    guard let url = URL(string: "https://example.com" + path) else {
        return .failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil))
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    if let accessToken = accessToken{
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    return await executeURLSession(request: request)
}

func performPutRequest(path: String, body: Data, accessToken: String? = nil ) async -> Result<Data, Error> {
    guard let url = URL(string: "https://example.com" + path) else {
        return .failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil))
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    if let accessToken = accessToken{
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    return await executeURLSession(request: request)
}

func performDeleteRequest(path: String, query: [String: Any] = [:], accessToken: String? = nil) async -> Result<Data, Error> {
    // 環境変数からベースURLを取得（例: "https://example.com"）
    guard var urlComponents = URLComponents(string: "https://example.com" + path) else {
        return .failure(NSError(domain: "Invalid base URL or path", code: -1, userInfo: nil))
    }
    // クエリパラメータを設定
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
    guard let url = urlComponents.url else {
        return .failure(NSError(domain: "Invalid Query Parameters", code: -1, userInfo: nil))
    }
    var request = URLRequest(url: url)
    request.httpMethod = "DELETE"
    if let accessToken = accessToken{
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
    return await executeURLSession(request: request)
}

//TODO
extension ApiError {
    static func factory(_ error: Error)->Self{
        return Self.unknown(error.localizedDescription)
    }
}
