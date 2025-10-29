//
//  APIRepositoryMock.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/02.
//

import Dependencies

extension APIRepotiroy: TestDependencyKey {
    internal static let testValue = Self.noop
    internal static let previewValue = Self.noop
}

var routes: [Route] = [Route.sample]

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
            let summaries = routes.map{ RouteSummary(from: RouteInfo(from: $0, name: "城北町")) }
            return Result.success(summaries)
        },
        getRoute: { id  in
            let route = routes.filter{ $0.id == id }.first ?? Route.sample
            return Result.success( RouteInfo(from: route, name: "城北町") )
        },
        getCurrentRoute: { _ in
            let route = routes.first ?? Route.sample
            return Result.success(CurrentResponse(districtId: "ID", districtName: "Name", routes: [RouteSummary.sample], current: RouteInfo.sample, location: LocationInfo.sample))
        },
        getRouteIds: {
            return Result.success(["id"])
        },
        postRoute: { route in
            routes.append(route)
            return Result.success("Success")
        },
        putRoute: { route in
            if let index = routes.firstIndex(where: { $0.id == route.id }) {
                routes[index] = route
            }
            return Result.success("Success")
        },
        deleteRoute: { id  in
            if let index = routes.firstIndex(where: { $0.id == id }) {
                routes.remove(at: index)
            }
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

