//
//  RemoteRepository.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Dependencies

struct ApiClient {
    var getRegions: () async  -> Result<[Region], ApiError>
    var getRegion: (_ regionId: String) async -> Result<Region, ApiError>
    var putRegion: (_ district: Region, _ accessToken: String) async -> Result<String, ApiError>
    var getDistricts: (_ regionId: String) async -> Result<[PublicDistrict], ApiError>
    var getDistrict: (_ districtId: String) async -> Result<PublicDistrict, ApiError>
    var postDistrict: (_ regionId: String, _ districtName: String, _ email: String, _ accessToken: String) async -> Result<String, ApiError>
    var putDistrict: (_ district: District, _ accessToken: String) async -> Result<String, ApiError>
    var getTool: (_ districtId: String, _ accessToken: String?) async -> Result<DistrictTool, ApiError>
    var getRoutes: (_ districtId: String, _ accessToken: String?) async -> Result<[RouteSummary], ApiError>
    var getRoute: (_ id: String, _ accessToken: String?) async -> Result<PublicRoute, ApiError>
    var getCurrentRoute: (_ districtId: String,_ accessToken: String?) async -> Result<PublicRoute, ApiError>
    var postRoute: (_ route: Route, _ accessToken: String) async -> Result<String, ApiError>
    var putRoute: (_ route: Route, _ accessToken: String) async -> Result<String, ApiError>
    var deleteRoute: (_ id: String, _ accessToken: String) async -> Result<String, ApiError>
    var getLocation: (_ districtId: String, _ accessToken: String?) async -> Result<PublicLocation?, ApiError>
    var getLocations: (_ regionId: String, _ accessToken: String?) async -> Result<[PublicLocation], ApiError>
    var putLocation: (_ location: Location,_ accessToken: String) async -> Result<String, ApiError>
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
    case unauthorized(String)
    case unknown(String)
    
    var localizedDescription: String {
        switch self {
        case .network(let message):
            return "通信中に問題が発生しました。 \n\(message)"
        case .encoding(let message):
            return "データの変換中に問題が発生しました。 \n\(message)"
        case .decoding(let message):
            return "受け取ったデータの読み取りに失敗しました。 \n\(message)"
        case .unauthorized(let message):
            return "ログインの有効期限が切れました。\nもう一度ログインしてください。 \n\(message)"
        case .unknown(let message):
            return "予期しないエラーが発生しました。 \n\(message)"
        }
    }
}
