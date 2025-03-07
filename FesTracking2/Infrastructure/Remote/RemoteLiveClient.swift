//
//  LiveRepository.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import Dependencies

extension RemoteClient: DependencyKey {
    static let liveValue = Self(
        getRegions: {
            let responce = await performGetRequest(
                path: "/region"
            )
            return decodeResponse([Region].self, from: responce)
        },
        getDistricts: { id in
            let responce = await performGetRequest(
                path: "/district",
                query: ["id":id.uuidString]
            )
            return decodeResponse([District].self, from: responce)
        },
        getRouteSummaries: { id in
            let responce = await performGetRequest(
                path: "/route/summaries",
                query: ["id":id.uuidString]
            )
            return decodeResponse([RouteSummary].self, from: responce)
        },
        getRoute: { id in
            let responce = await performGetRequest(
                path: "/route/detail",
                query: ["id":id.uuidString]
            )
            return decodeResponse(Route.self, from: responce)
        },
        postRoute: { route in
            let body = encodeRequest(route)
            switch body {
            case .success(let body):
                let responce = await performPostRequest(path: "/route", body: body)
                return decodeResponse(String.self, from: responce)
            case .failure(let failure):
                return Result.failure(RemoteError.encodingError(failure.localizedDescription))
            }
            
        },
        deleteRoute: { id in
            let responce = await performDeleteRequest(
                path: "/route",
                query: ["id":id.uuidString]
            )
            return decodeResponse(String.self, from: responce)
        },
        getSegmentCoordinate: { coordinate1, coordinate2 in
            let responce = await performGetRequest(
                path: "/route/detail",
                query: [
                    "lat1": coordinate1.latitude,
                    "lon1": coordinate1.longitude,
                    "lat2": coordinate2.latitude,
                    "lon2": coordinate2.longitude
                ]
            )
            return decodeResponse([Coordinate].self, from: responce)
        }
    )
    static private func decodeResponse<T:Codable>(_ type:T.Type, from responce: Result<Data,Error>)->Result<T,RemoteError>{
        switch responce {
        case .success(let data):
            do{
                let decodedObject = try JSONDecoder().decode(type, from: data)
                return Result.success(decodedObject)
            }catch{
                //TODO
                return Result.failure(RemoteError.decodingError("レスポンスの解析に失敗しました"))
            }
        case .failure(let error):
            return Result.failure(RemoteError.networkError(error.localizedDescription))
        }
    }
    static private func encodeRequest<T: Encodable>(_ object: T) -> Result<Data, Error> {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted // オプション: JSONを見やすくする
        do {
            let data = try encoder.encode(object)
            return .success(data)
        } catch {
            return .failure(error)
        }
    }
}

func performGetRequest(path: String, query: [String: Any] = [:]) async -> Result<Data, Error> {
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

func performPostRequest(path: String, body: Data) async -> Result<Data, Error> {
    guard let url = URL(string: "https://example.com" + path) else {
        return .failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil))
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) {
            return .success(data)
        } else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            return .failure(NSError(domain: "HTTP Error", code: statusCode, userInfo: nil))
        }
    } catch {
        return .failure(error)
    }
}

func performDeleteRequest(path: String, query: [String: String] = [:]) async -> Result<Data, Error> {
    guard let baseUrl = ProcessInfo.processInfo.environment["BASE_URL"],
          var urlComponents = URLComponents(string: baseUrl + path) else {
        return .failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil))
    }
    // クエリパラメータを追加
    urlComponents.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
    
    guard let url = urlComponents.url else {
        return .failure(NSError(domain: "Invalid Query Parameters", code: -1, userInfo: nil))
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "DELETE"
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) {
            return .success(data)
        } else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            return .failure(NSError(domain: "HTTP Error", code: statusCode, userInfo: nil))
        }
    } catch {
        return .failure(error)
    }
}

//TODO
extension RemoteError {
    static func factory(_ error: Error)->Self{
        return Self.unknownError(error.localizedDescription)
    }
}
