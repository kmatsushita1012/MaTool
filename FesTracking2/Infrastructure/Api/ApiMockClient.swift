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
        getRegions: {
            return Result.success([Region.sample])
        },
        getRegion:{ _ in
            return Result.success(Region.sample)
        },
        putRegion: { _,_ in
            return Result.success("Success")
        },
        getDistricts: { _ in
            return Result.success([PublicDistrict.sample])
        },
        getDistrict: { _ in
            return Result.success(PublicDistrict.sample)
        },
        postDistrict: { _,_ in
            return Result.success("Success")
        },
        putDistrict: { _,_ in
            return Result.success("Success")
        },
        getRoutes: { _ in
            return Result.success([RouteSummary.sample,route2])
        },
        getRoute: { _,_,_  in
            return Result.success(PublicRoute.sample)
        },
        getCurrentRoute: { _ in
            return Result.success(PublicRoute.sample)
        },
        getLocation: { _ in
            return Result.success(PublicLocation.sample)
        },
        getLocations: { _ in
            return Result.success([PublicLocation.sample])
        },
        postRoute: { _,_ in
            return Result.success("Success")
        },
        putRoute: { _,_ in
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

let route2 = RouteSummary(districtId: "johoku", districtName: "城北町", date: SimpleDate.sample, title: "午前", visibility: .all)
