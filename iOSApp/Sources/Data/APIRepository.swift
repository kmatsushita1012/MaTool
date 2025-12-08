//
//  RemoteRepository.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/02.
//

import Dependencies
import Shared
import Foundation

// MARK: - Dependencies
extension DependencyValues {
  var apiRepository: APIRepotiroy {
    get { self[APIRepotiroy.self] }
    set { self[APIRepotiroy.self] = newValue }
  }
}

// MARK: - APIRepository(Protocol)
struct APIRepotiroy: Sendable {
    @Dependency(\.apiClient) var apiClient
    
    var getFestivals: @Sendable () async  -> Result<[Festival], APIError>
    var getFestival: @Sendable (_ festivalId: String) async -> Result<Festival, APIError>
    var putFestival: @Sendable (_ district: Festival) async -> Result<Festival, APIError>
    var getDistricts: @Sendable (_ festivalId: String) async -> Result<[District], APIError>
    var getDistrict: @Sendable (_ districtId: String) async -> Result<District, APIError>
    var postDistrict: @Sendable (_ festivalId: String, _ districtName: String, _ email: String) async -> Result<District, APIError>
    var putDistrict: @Sendable (_ district: District) async -> Result<District, APIError>
    var getTool: @Sendable (_ districtId: String) async -> Result<DistrictTool, APIError>
    var getRoutes: @Sendable (_ districtId: String) async -> Result<[RouteItem], APIError>
    var getRoute: @Sendable (_ id: String) async -> Result<Route, APIError>
    var getCurrentRoute: @Sendable (_ districtId: String) async -> Result<CurrentResponse, APIError>
    var getRouteIds: @Sendable () async -> Result<[String], APIError>
    var postRoute: @Sendable (_ route: Route) async -> Result<Route, APIError>
    var putRoute: @Sendable (_ route: Route) async -> Result<Route, APIError>
    var deleteRoute: @Sendable (_ id: String) async -> Result<Empty, APIError>
    var getLocation: @Sendable (_ districtId: String) async -> Result<FloatLocationGetDTO, APIError>
    var getLocations: @Sendable (_ festivalId: String) async -> Result<[FloatLocationGetDTO], APIError>
    var putLocation: @Sendable (_ location: FloatLocation) async -> Result<FloatLocation, APIError>
    var deleteLocation: @Sendable (_ districtId: String) async -> Result<Empty, APIError>
    //MARK: - Program
    var getLatestProgram: @Sendable (_ festivalId: String) async -> Result<Program, APIError>
    var getProgram: @Sendable (_ festivalId: String, _ year: Int) async -> Result<Program, APIError>
    var getPrograms: @Sendable (_ festivalId: String) async -> Result<[Program], APIError>
    var postProgram: @Sendable (_ program: Program) async -> Result<Program, APIError>
    var putProgram: @Sendable (_ program: Program) async -> Result<Program, APIError>
    var deleteProgram: @Sendable (_ festivalId: String, _ year: Int) async -> Result<Empty, APIError>
    
}

// MARK: - APIRepository
extension APIRepotiroy: DependencyKey {
    static let liveValue = {
        @Dependency(\.authService) var authService
        @Dependency(\.apiClient) var apiClient
        
        return Self(
            getFestivals: {
                let response: Result<[Festival], APIError> = await apiClient.get(
                    path: "/festivals"
                )
                return response
            },
            getFestival: { id in
                let response: Result<Festival, APIError> = await apiClient.get(
                    path: "/festivals/\(id)"
                )
                return response
            },
            putFestival: { festival in
                let accessToken = await authService.getAccessToken()
                let response: Result<Festival, APIError> = await apiClient.put(
                    path: "/festivals/\(festival.id)",
                    body: festival,
                    accessToken: accessToken
                )
                return response
            },
            getDistricts: { festivalId in
                let response: Result<[District], APIError> = await apiClient.get(
                    path: "/festivals/\(festivalId)/districts"
                )
                return response
            },
            getDistrict: { id in
                let response: Result<District, APIError> = await apiClient.get(
                    path: "/districts/\(id)"
                )
                return response
            },
            postDistrict: { festivalId, districtName, email in
                struct DistrictCreateBody: Encodable {
                    let name: String
                    let email: String
                }
                let body = DistrictCreateBody(name: districtName, email: email)
                let accessToken = await authService.getAccessToken()
                let response: Result<District, APIError> = await apiClient.post(
                    path: "/festivals/\(festivalId)/districts",
                    body: body,
                    accessToken: accessToken
                )
                return response
            },
            putDistrict: { district in
                let accessToken = await authService.getAccessToken()
                let response: Result<District, APIError> = await apiClient.put(
                    path: "/districts/\(district.id)",
                    body: district,
                    accessToken: accessToken
                )
                return response
            },
            getTool: { districtId in
                let accessToken = await authService.getAccessToken()
                let response: Result<DistrictTool, APIError> = await apiClient.get(
                    path: "/districts/\(districtId)/tools",
                    accessToken: accessToken
                )
                return response
            },
            getRoutes: { districtId in
                let accessToken = await authService.getAccessToken()
                let response: Result<[RouteItem], APIError> = await apiClient.get(
                    path: "/districts/\(districtId)/routes",
                    accessToken: accessToken,
                    isCache: true
                )
                return response
            },
            getRoute: { id in
                let accessToken = await authService.getAccessToken()
                let response: Result<Route, APIError> = await apiClient.get(
                    path: "/routes/\(id)",
                    accessToken: accessToken,
                    isCache: false
                )
                return response
            },
            getCurrentRoute: { districtId in
                let accessToken = await authService.getAccessToken()
                let response: Result<CurrentResponse, APIError> = await apiClient.get(
                    path: "/districts/\(districtId)/routes/current",
                    accessToken: accessToken,
                    isCache: false
                )
                return response
            },
            getRouteIds: {
                let accessToken = await authService.getAccessToken()
                let response: Result<[String], APIError> = await apiClient.get(
                    path: "/routes",
                    accessToken: accessToken,
                    isCache: false
                )
                return response
            },
            postRoute: { route in
                let accessToken = await authService.getAccessToken()
                let response: Result<Route, APIError> = await apiClient.post(
                    path: "/districts/\(route.districtId)/routes",
                    body: route,
                    accessToken: accessToken
                )
                return response
            },
            putRoute: { route in
                let accessToken = await authService.getAccessToken()
                let response: Result<Route, APIError> = await apiClient.put(
                    path: "/routes/\(route.id)",
                    body: route,
                    accessToken: accessToken
                )
                return response
            },
            deleteRoute: { id in
                let accessToken = await authService.getAccessToken()
                let response: Result<Empty, APIError> = await apiClient.delete(
                    path: "/routes/\(id)",
                    accessToken: accessToken
                )
                return response
            },
            getLocation: { districtId in
                let accessToken = await authService.getAccessToken()
                let response: Result<FloatLocationGetDTO, APIError> = await apiClient.get(
                    path: "/districts/\(districtId)/locations",
                    accessToken: accessToken,
                    isCache: false
                )
                return response
            },
            getLocations: { festivalId in
                let accessToken = await authService.getAccessToken()
                let response: Result<[FloatLocationGetDTO], APIError> = await apiClient.get(
                    path: "/festivals/\(festivalId)/locations",
                    accessToken: accessToken,
                    isCache: false
                )
                return response
            },
            putLocation: { location in
                let accessToken = await authService.getAccessToken()
                let response: Result<FloatLocation, APIError> = await apiClient.put(
                    path: "/districts/\(location.districtId)/locations",
                    body: location,
                    accessToken: accessToken
                )
                return response
            },
            deleteLocation: { id in
                let accessToken = await authService.getAccessToken()
                let response: Result<Empty, APIError> = await apiClient.delete(
                    path: "/districts/\(id)/locations",
                    accessToken: accessToken
                )
                return response
            },
            getLatestProgram: { festivalId in
                let response: Result<Program, APIError> = await apiClient.get(
                    path: "/festivals/\(festivalId)/programs/latest"
                )
                return response
            },
            getProgram: { festivalId, year in
                let response: Result<Program, APIError> = await apiClient.get(
                    path: "/festivals/\(festivalId)/programs/\(year)"
                )
                return response
            },
            getPrograms: { festivalId in
                let response: Result<[Program], APIError> = await apiClient.get(
                    path: "/festivals/\(festivalId)/programs"
                )
                return response
            },
            postProgram: { program in
                let accessToken = await authService.getAccessToken()
                let response: Result<Program, APIError> = await apiClient.post(
                    path: "/festivals/\(program.festivalId)/programs",
                    body: program,
                    accessToken: accessToken
                )
                return response
            },
            putProgram: { program in
                let accessToken = await authService.getAccessToken()
                let response: Result<Program, APIError> = await apiClient.put(
                    path: "/festivals/\(program.festivalId)/programs/\(program.year)",
                    body: program,
                    accessToken: accessToken
                )
                return response
            },
            deleteProgram: { festivalId, year in
                let accessToken = await authService.getAccessToken()
                let response: Result<Empty, APIError> = await apiClient.delete(
                    path: "/festivals/\(festivalId)/programs/\(year)",
                    accessToken: accessToken
                )
                return response
            }
        )
    }()
}
