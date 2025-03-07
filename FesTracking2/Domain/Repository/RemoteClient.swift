//
//  RemoteRepository.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import DependenciesMacros
import Dependencies
import Combine
import ComposableArchitecture

struct AWSClient {
    var getRegions: () async  -> Result<[Region], RemoteError>
    var getDistricts: (_ regionId: UUID) async -> Result<[District], RemoteError>
    var getRouteSummaries: (_ districtId: UUID) async -> Result<[RouteSummary], RemoteError>
    var getRoute: (_ routeId: UUID) async -> Result<Route, RemoteError>
    var postRoute: (_ route: Route) async -> Result<String, RemoteError>
    var deleteRoute: (_ routeId: UUID) async -> Result<String, RemoteError>
    var getSegmentCoordinate: (_ start: Coordinate, _ end: Coordinate) async -> Result<[Coordinate],RemoteError>
}


extension DependencyValues {
  var awsClient: AWSClient {
    get { self[AWSClient.self] }
    set { self[AWSClient.self] = newValue }
  }
}


enum RemoteError: Error, Equatable {
    case networkError(String)
    case decodingError(String)
    case unknownError(String)
    
    var localizedDescription: String {
        switch self {
        case .networkError(let message):
            return "Network Error: \(message)"
        case .decodingError(let message):
            return "Decoding Error: \(message)"
        case .unknownError(let message):
            return "Unknown Error: \(message)"
        }
    }
}
