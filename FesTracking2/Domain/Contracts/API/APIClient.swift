//
//  APIClient.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/08/19.
//

import Dependencies
import Foundation

protocol APIClientProtocol {

    func request(
        path: String,
        method: String,
        query: [String: Any],
        body: Data?,
        accessToken: String?,
        isCache: Bool
    ) async -> Result<Data, APIError>

    func get(
        path: String,
        query: [String: Any],
        accessToken: String?,
        isCache: Bool
    ) async -> Result<Data, APIError>

    func post(
        path: String,
        body: Data,
        query: [String: Any],
        accessToken: String?
    ) async -> Result<Data, APIError>

    func put(
        path: String,
        body: Data,
        query: [String: Any],
        accessToken: String?
    ) async -> Result<Data, APIError>

    func delete(
        path: String,
        query: [String: Any],
        accessToken: String?
    ) async -> Result<Data, APIError>
}

extension APIClientProtocol {
    // デフォルト値付き request
    func request(
        path: String,
        method: String,
        query: [String: Any] = [:],
        body: Data? = nil,
        accessToken: String? = nil,
        isCache: Bool = true
    ) async -> Result<Data, APIError> {
        await self.request(
            path: path,
            method: method,
            query: query,
            body: body,
            accessToken: accessToken,
            isCache: isCache
        )
    }
    
    func get(
        path: String,
        query: [String: Any] = [:],
        accessToken: String? = nil,
        isCache: Bool = true
    ) async -> Result<Data, APIError> {
        await self.get(
            path: path,
            query: query,
            accessToken: accessToken,
            isCache: isCache
        )
    }
    
    func post(
        path: String,
        body: Data,
        query: [String: Any] = [:],
        accessToken: String? = nil
    ) async -> Result<Data, APIError> {
        await self.post(
            path: path,
            body: body,
            query: query,
            accessToken: accessToken
        )
    }
    
    func put(
        path: String,
        body: Data,
        query: [String: Any] = [:],
        accessToken: String? = nil
    ) async -> Result<Data, APIError> {
        await self.put(
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
    ) async -> Result<Data, APIError> {
        await self.delete(
            path: path,
            query: query,
            accessToken: accessToken
        )
    }
}

enum APIClientKey: DependencyKey {
    static let liveValue: any APIClientProtocol = APIClient.init(base: "https://eqp8rvam4h.execute-api.ap-northeast-1.amazonaws.com")
}

extension DependencyValues {
    var apiClient: any APIClientProtocol {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

