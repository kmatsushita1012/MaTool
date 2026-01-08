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
    var getLocation: @Sendable (_ districtId: String) async -> Result<FloatLocationGetDTO, APIError>
    var getLocations: @Sendable (_ festivalId: String) async -> Result<[FloatLocationGetDTO], APIError>
    var putLocation: @Sendable (_ location: FloatLocation) async -> Result<FloatLocation, APIError>
    var deleteLocation: @Sendable (_ districtId: String) async -> Result<Empty, APIError>
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
            }
        )
    }()
}
