//
//  RouteRemoteRepository.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/29.
//

import Dependencies
import Shared

// MARK: - Dependencies
enum RouteRemoteRepositoryKey: DependencyKey {
    static let liveValue: RouteRemoteRepositoryProtocol = RouteRemoteRepository()
}

protocol RouteRemoteRepositoryProtocol: Sendable {

    // GET /routes/:routeId
    func get(routeId: String) async -> Result<RouteResponse, APIError>

    // GET /routes?districtId=...
    func query(districtId: String) async -> Result<RoutesResponse, APIError>

    // GET /routes?districtId=...&year=...
    func query(districtId: String, year: Int) async -> Result<RoutesResponse, APIError>

    // POST /routes?districtId=...
    func post(districtId: String, route: Route) async -> Result<Route, APIError>

    // PUT /routes/:routeId
    func put(routeId: String, route: Route) async -> Result<Route, APIError>

    // DELETE /routes/:routeId
    func delete(routeId: String) async -> Result<Empty, APIError>

    // GET /routes/current?districtId=...
    func getCurrent(districtId: String) async -> Result<CurrentResponse, APIError>
    
    // GET /routes/current?districtId=...&periodId=...
    func getCurrent(districtId: String, periodId: String) async -> Result<CurrentResponse, APIError>

    // GET /routes/ids
    func getIds() async -> Result<[String], APIError>
}

struct RouteRemoteRepository: RouteRemoteRepositoryProtocol {

    @Dependency(\.apiClient) private var apiClient
    @Dependency(\.authService) private var authService

    init() {}

    func get(routeId: String) async -> Result<RouteResponse, APIError> {
        let accessToken = await authService.getAccessToken()
        return await apiClient.get(
            path: "/routes/\(routeId)",
            accessToken: accessToken,
            isCache: false
        )
    }

    func query(districtId: String) async -> Result<RoutesResponse, APIError> {
        let accessToken = await authService.getAccessToken()
        return await apiClient.get(
            path: "/routes",
            query: ["districtId": districtId],
            accessToken: accessToken,
            isCache: false
        )
    }

    func query(districtId: String, year: Int) async -> Result<RoutesResponse, APIError> {
        let accessToken = await authService.getAccessToken()
        return await apiClient.get(
            path: "/routes",
            query: [
                "districtId": districtId,
                "year": String(year)
            ],
            accessToken: accessToken,
            isCache: false
        )
    }

    func post(districtId: String, route: Route) async -> Result<Route, APIError> {
        let accessToken = await authService.getAccessToken()
        return await apiClient.post(
            path: "/routes",
            body: route,
            query: ["districtId": districtId],
            accessToken: accessToken
        )
    }

    func put(routeId: String, route: Route) async -> Result<Route, APIError> {
        let accessToken = await authService.getAccessToken()
        return await apiClient.put(
            path: "/routes/\(routeId)",
            body: route,
            accessToken: accessToken
        )
    }

    func delete(routeId: String) async -> Result<Empty, APIError> {
        let accessToken = await authService.getAccessToken()
        return await apiClient.delete(
            path: "/routes/\(routeId)",
            accessToken: accessToken
        )
    }

    func getCurrent(districtId: String) async -> Result<CurrentResponse, APIError> {
        let accessToken = await authService.getAccessToken()
        return await apiClient.get(
            path: "/routes/current",
            query: ["districtId": districtId],
            accessToken: accessToken,
            isCache: false
        )
    }
    
    func getCurrent(districtId: String, periodId: String) async -> Result<CurrentResponse, APIError> {
        let accessToken = await authService.getAccessToken()
        return await apiClient.get(
            path: "/routes/current",
            query: ["districtId": districtId, "periodId": periodId],
            accessToken: accessToken,
            isCache: false
        )
    }

    func getIds() async -> Result<[String], APIError> {
        let accessToken = await authService.getAccessToken()
        return await apiClient.get(
            path: "/routes/ids",
            accessToken: accessToken,
            isCache: false
        )
    }
}
