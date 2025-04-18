//
//  MockRepository.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Dependencies

extension ApiClient: TestDependencyKey {
    internal static let testValue = Self.noop
    internal static let previewValue = Self.noop
}

extension ApiClient {
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
