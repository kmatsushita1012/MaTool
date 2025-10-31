//
//  RemoteRepository.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/02.
//

import Dependencies

struct APIRepotiroy: Sendable {
    @Dependency(\.apiClient) var apiClient
    
    var getRegions: @Sendable () async  -> Result<[Region], APIError>
    var getRegion: @Sendable (_ regionId: String) async -> Result<Region, APIError>
    var putRegion: @Sendable (_ district: Region) async -> Result<String, APIError>
    var getDistricts: @Sendable (_ regionId: String) async -> Result<[District], APIError>
    var getDistrict: @Sendable (_ districtId: String) async -> Result<District, APIError>
    var postDistrict: @Sendable (_ regionId: String, _ districtName: String, _ email: String) async -> Result<String, APIError>
    var putDistrict: @Sendable (_ district: District) async -> Result<String, APIError>
    var getTool: @Sendable (_ districtId: String) async -> Result<DistrictTool, APIError>
    var getRoutes: @Sendable (_ districtId: String) async -> Result<[RouteSummary], APIError>
    var getRoute: @Sendable (_ id: String) async -> Result<RouteInfo, APIError>
    var getCurrentRoute: @Sendable (_ districtId: String) async -> Result<CurrentResponse, APIError>
    var getRouteIds: @Sendable () async -> Result<[String], APIError>
    var postRoute: @Sendable (_ route: Route) async -> Result<String, APIError>
    var putRoute: @Sendable (_ route: Route) async -> Result<String, APIError>
    var deleteRoute: @Sendable (_ id: String) async -> Result<String, APIError>
    var getLocation: @Sendable (_ districtId: String) async -> Result<LocationInfo, APIError>
    var getLocations: @Sendable (_ regionId: String) async -> Result<[LocationInfo], APIError>
    var putLocation: @Sendable (_ location: Location) async -> Result<String, APIError>
    var deleteLocation: @Sendable (_ districtId: String) async -> Result<String, APIError>
}

extension DependencyValues {
  var apiRepository: APIRepotiroy {
    get { self[APIRepotiroy.self] }
    set { self[APIRepotiroy.self] = newValue }
  }
}


