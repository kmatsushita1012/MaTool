//
//  RemoteRepository.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import Dependencies

struct RemoteClient {
    var getRegions: () async  -> Result<[Region], RemoteError>
    var getDistricts: (_ regionId: UUID) async -> Result<[District], RemoteError>
    var getRouteSummaries: (_ districtId: UUID) async -> Result<[RouteSummary], RemoteError>
    var getRoute: (_ routeId: UUID) async -> Result<Route, RemoteError>
    var postRoute: (_ route: Route) async -> Result<String, RemoteError>
    var deleteRoute: (_ routeId: UUID) async -> Result<String, RemoteError>
    var getSegmentCoordinate: (_ start: Coordinate, _ end: Coordinate) async -> Result<[Coordinate],RemoteError>
}

extension RemoteClient {
    public static let noop = Self(
        getRegions:{
            return Result.success([Region(id: UUID(), name: "掛川祭", description: "省略", imagePath: nil)])
        },
        getDistricts: {_ in
            return Result.success([District(id: UUID(), name: "城北町", description: "省略", imagePath: nil)])
        },
        getRouteSummaries: {_ in
            return Result.success([RouteSummary(id: UUID(), date: SimpleDate(year: 2025, month: 10, day: 12), title: "午前")])
            
        },
        getRoute: {_ in
            return Result.success(
                Route(
                    id: UUID(),
                    date: SimpleDate(year: 2025, month: 10, day: 12),
                    title: "午後",
                    points: [
                        Point(id: UUID(),coordinate: Coordinate(latitude: 34.777681, longitude: 138.007029), title: "出発", description: nil, time: Time(hour: 9, minute: 0),isPassed: true),
                        Point(id: UUID(),coordinate: Coordinate(latitude: 34.778314, longitude: 138.008176), title: "到着", description: "お疲れ様です", time: Time(hour: 12, minute: 0),isPassed: true)
                    ],
                    segments: [
                        Segment(
                            id: UUID(),
                            start: Coordinate(latitude: 34.777681, longitude: 138.007029),
                            end: Coordinate(latitude: 34.778314, longitude: 138.008176)
                        )
                    ],
                    current: Location(coordinate: Coordinate(latitude: 34.777681, longitude: 138.007029),time: Time(hour: 9, minute: 1)),
                    description: "省略",
                    start: Time(
                        hour:9,
                        minute:00
                    ),
                    goal: Time(
                        hour:12,
                        minute: 00
                    )
                )
            )
        },
        postRoute: {_ in
            return Result.success("Success")
        },
        deleteRoute: {_ in
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
    case networkError(String)
    case encodingError(String)
    case decodingError(String)
    case unknownError(String)
    
    var localizedDescription: String {
        switch self {
        case .networkError(let message):
            return "Network Error: \(message)"
        case .encodingError(let message):
            return "Encoding Error: \(message)"
        case .decodingError(let message):
            return "Decoding Error: \(message)"
        case .unknownError(let message):
            return "Unknown Error: \(message)"
        }
    }
}
