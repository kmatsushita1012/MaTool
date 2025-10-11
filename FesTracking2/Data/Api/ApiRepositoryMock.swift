//
//  APIRepositoryMock.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Dependencies

extension APIRepotiroy: TestDependencyKey {
    internal static let testValue = Self.noop
    internal static let previewValue = Self.noop
}


extension APIRepotiroy {
    public static let noop = Self(
        getRegions: {
            return Result.success([Region.sample])
        },
        getRegion:{ _ in
            return Result.success(Region.sample)
        },
        putRegion: { _ in
            return Result.success("Success")
        },
        getDistricts: { _ in
            return Result.success([PublicDistrict.sample])
        },
        getDistrict: { _ in
            return Result.success(PublicDistrict.sample)
        },
        postDistrict: { _,_,_ in
            return Result.success("Success")
        },
        putDistrict: { _ in
            return Result.success("Success")
        },
        getTool: { _ in
            return Result.success(DistrictTool.sample)
        },
        getRoutes: { _ in
            return Result.success([RouteSummary.sample])
        },
        getRoute: { id  in
            return Result.success( RouteInfo.sample )
        },
        getCurrentRoute: { _ in
            return Result.success(CurrentResponse(districtId: "ID", districtName: "Name", routes: [RouteSummary.sample], current: RouteInfo.sample, location: LocationInfo.sample))
        },
        getRouteIds: {
            return Result.success(["id"])
        },
        postRoute: { route in
            return Result.success("Success")
        },
        putRoute: { route in
            return Result.success("Success")
        },
        deleteRoute: { id  in
            return Result.success("Success")
        },
        getLocation: { _ in
            return Result.success(LocationInfo.sample)
        },
        getLocations: { _ in
            return Result.success([LocationInfo.sample])
        },
        putLocation: { _ in
            return Result.success("Success")
        },
        deleteLocation: { _ in
            return Result.success("Success")
        }
    )
}

