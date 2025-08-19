//
//  RemoteRepository.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Dependencies

struct APIRepotiroy: Sendable {
    var getRegions: @Sendable () async  -> Result<[Region], ApiError>
    var getRegion: @Sendable (_ regionId: String) async -> Result<Region, ApiError>
    var putRegion: @Sendable (_ district: Region, _ accessToken: String) async -> Result<String, ApiError>
    var getDistricts: @Sendable (_ regionId: String) async -> Result<[PublicDistrict], ApiError>
    var getDistrict: @Sendable (_ districtId: String) async -> Result<PublicDistrict, ApiError>
    var postDistrict: @Sendable (_ regionId: String, _ districtName: String, _ email: String, _ accessToken: String) async -> Result<String, ApiError>
    var putDistrict: @Sendable (_ district: District, _ accessToken: String) async -> Result<String, ApiError>
    var getTool: @Sendable (_ districtId: String, _ accessToken: String?) async -> Result<DistrictTool, ApiError>
    var getRoutes: @Sendable (_ districtId: String, _ accessToken: String?) async -> Result<[RouteSummary], ApiError>
    var getRoute: @Sendable (_ id: String, _ accessToken: String?) async -> Result<RouteInfo, ApiError>
    var getCurrentRoute: @Sendable (_ districtId: String,_ accessToken: String?) async -> Result<RouteInfo, ApiError>
    var getRouteIds: @Sendable (_ accessToken: String?) async -> Result<[String], ApiError>
    var postRoute: @Sendable (_ route: Route, _ accessToken: String) async -> Result<String, ApiError>
    var putRoute: @Sendable (_ route: Route, _ accessToken: String) async -> Result<String, ApiError>
    var deleteRoute: @Sendable (_ id: String, _ accessToken: String) async -> Result<String, ApiError>
    var getLocation: @Sendable (_ districtId: String, _ accessToken: String?) async -> Result<LocationInfo, ApiError>
    var getLocations: @Sendable (_ regionId: String, _ accessToken: String?) async -> Result<[LocationInfo], ApiError>
    var putLocation: @Sendable (_ location: Location,_ accessToken: String) async -> Result<String, ApiError>
    var deleteLocation: @Sendable (_ districtId: String,_ accessToken: String) async -> Result<String, ApiError>
    var getSegmentCoordinate: @Sendable (_ start: Coordinate, _ end: Coordinate) async -> Result<[Coordinate],ApiError>
}

extension DependencyValues {
  var apiRepository: APIRepotiroy {
    get { self[APIRepotiroy.self] }
    set { self[APIRepotiroy.self] = newValue }
  }
}


