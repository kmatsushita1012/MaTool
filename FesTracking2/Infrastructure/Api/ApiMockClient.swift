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

var routes: [Route] = [Route.sample]

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
        postDistrict: { _,_,_,_ in
            return Result.success("Success")
        },
        putDistrict: { _,_ in
            return Result.success("Success")
        },
        getRoutes: { _,_ in
            let summaries = routes.map{ RouteSummary(from: PublicRoute(from: $0, name: "城北町")) }
            return Result.success(summaries)
        },
        getRoute: { id, _  in
            let route = routes.filter{ $0.id == id }.first ?? Route.sample
            return Result.success( PublicRoute(from: route, name: "城北町") )
        },
        getCurrentRoute: { _,_ in
            let route = routes.first ?? Route.sample
            return Result.success(PublicRoute(from: route, name: "城北町"))
        },
        postRoute: { route,_ in
            routes.append(route)
            return Result.success("Success")
        },
        putRoute: { route,_ in
            if let index = routes.firstIndex(where: { $0.id == route.id }) {
                routes[index] = route
            }
            return Result.success("Success")
        },
        deleteRoute: { id, _  in
            if let index = routes.firstIndex(where: { $0.id == id }) {
                routes.remove(at: index)
            }
            return Result.success("Success")
        },
        getLocation: { _,_ in
            return Result.success(PublicLocation.sample)
        },
        getLocations: { _,_ in
            return Result.success([PublicLocation.sample])
        },
        putLocation: { _,_ in
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

