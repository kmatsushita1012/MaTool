//
//  RemoteRepository.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Dependencies

struct ApiClient {
    var getRegionSummaries: () async  -> Result<[RegionSummary], ApiError>
    var getRegionDetail: (_ regionId: String) async -> Result<Region, ApiError>
    var getDistrictSummaries: (_ regionId: String) async -> Result<[DistrictSummary], ApiError>
    var getDistrictDetail: (_ districtId: String) async -> Result<District, ApiError>
    var getRouteSummaries: (_ districtId: String) async -> Result<[RouteSummary], ApiError>
    var getRouteDetail: (_ districtId: String, _ date: SimpleDate?, _ title: String?) async -> Result<Route, ApiError>
    var getLocation: (_ districtId: String) async -> Result<Location?, ApiError>
    var postRegion: (_ region: Region, _ accessToken: String) async -> Result<String, ApiError>
    var postDistrict: (_ district: District, _ accessToken: String) async -> Result<String, ApiError>
    var postRoute: (_ route: Route,_ accessToken: String) async -> Result<String, ApiError>
    var deleteRoute: (_ districtId: String,_ date:SimpleDate, _ title:String,_ accessToken: String) async -> Result<String, ApiError>
    var postLocation: (_ location: Location,_ accessToken: String) async -> Result<String, ApiError>
    var deleteLocation: (_ districtId: String,_ accessToken: String) async -> Result<String, ApiError>
    var getSegmentCoordinate: (_ start: Coordinate, _ end: Coordinate) async -> Result<[Coordinate],ApiError>
}

extension DependencyValues {
  var apiClient: ApiClient {
    get { self[ApiClient.self] }
    set { self[ApiClient.self] = newValue }
  }
}


enum ApiError: Error, Equatable {
    case network(String)
    case encoding(String)
    case decoding(String)
    case unknown(String)
    
    var localizedDescription: String {
        switch self {
        case .network(let message):
            return "Network Error: \(message)"
        case .encoding(let message):
            return "Encoding Error: \(message)"
        case .decoding(let message):
            return "Decoding Error: \(message)"
        case .unknown(let message):
            return "Unknown Error: \(message)"
        }
    }
}
