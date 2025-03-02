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

struct RemoteClient {
    var getRegions: () async throws -> [Region]
    var getDistricts: (_ regionId: UUID) async throws -> [District]
    var getRouteList: (_ districtId: UUID) async throws -> [RouteSummary]
    var getRoute: (_ routeId: UUID) async -> Result<Route,RemoteError>
}



extension DependencyValues {
  var numberFact: RemoteClient {
    get { self[RemoteClient.self] }
    set { self[RemoteClient.self] = newValue }
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
