//
//  RemoteRepository.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Dependencies

struct RemoteClient {
    var getRegionSummaries: () async  -> Result<[RegionSummary], RemoteError>
    var getRegionDetail: (_ regionId: String) async -> Result<Region, RemoteError>
    var getDistrictSummaries: (_ regionId: String) async -> Result<[DistrictSummary], RemoteError>
    var getDistrictDetail: (_ districtId: String) async -> Result<District, RemoteError>
    var getRouteSummaries: (_ districtId: String) async -> Result<[RouteSummary], RemoteError>
    var getRouteDetail: (_ districtId: String, _ date: SimpleDate?, _ title: String?) async -> Result<Route, RemoteError>
    var getLocation: (_ districtId: String) async -> Result<Location, RemoteError>
    var postRegion: (_ region: Region, _ accessToken: String) async -> Result<String, RemoteError>
    var postDistrict: (_ district: District, _ accessToken: String) async -> Result<String, RemoteError>
    var postRoute: (_ route: Route,_ accessToken: String) async -> Result<String, RemoteError>
    var deleteRoute: (_ districtId: String,_ date:SimpleDate, _ title:String,_ accessToken: String) async -> Result<String, RemoteError>
    var postLocation: (_ location: Location,_ accessToken: String) async -> Result<String, RemoteError>
    var deleteLocation: (_ districtId: String,_ accessToken: String) async -> Result<String, RemoteError>
    var getSegmentCoordinate: (_ start: Coordinate, _ end: Coordinate) async -> Result<[Coordinate],RemoteError>
}

extension RemoteClient {
    public static let noop = Self(
        getRegionSummaries: {
            return Result.success([RegionSummary.sample])
        },
        getRegionDetail:{ _ in
            return Result.success(Region.sample)
        },
        getDistrictSummaries: { _ in
            return Result.success([DistrictSummary.sample])
        },
        getDistrictDetail: { _ in
            return Result.success(District.sample)
        },
        getRouteSummaries: { _ in
            return Result.success([RouteSummary.sample])
        },
        getRouteDetail: { _,_,_  in
            print("remote mock")
            return Result.success(Route.sample)
        },
        getLocation: { _ in
            return Result.success(Location.sample)
        },
        postRegion: { _,_ in
            return Result.success("Success")
        },
        postDistrict: { _,_ in
            return Result.success("Success")
        },
        postRoute: { _,_ in
            return Result.success("Success")
        },
        deleteRoute: { _,_,_,_  in
            return Result.success("Success")
        },
        
        postLocation: { _,_ in
            return Result.success("Success")
        },
        deleteLocation: { _,_ in
            return Result.success("Success")
        },
        getSegmentCoordinate: { start, end in
            let mid = Coordinate(latitude: (start.latitude + end.latitude)/2, longitude: (start.latitude + end.latitude)/2)
            return Result.success([start, mid, end])
        }
    )
}


extension DependencyValues {
  var remoteClient: RemoteClient {
    get { self[RemoteClient.self] }
    set { self[RemoteClient.self] = newValue }
  }
}


enum RemoteError: Error, Equatable {
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
