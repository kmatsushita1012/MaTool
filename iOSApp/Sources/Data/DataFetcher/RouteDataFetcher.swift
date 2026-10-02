//
//  RouteDataFetcher.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/13.
//

import Shared
import Dependencies
import SQLiteData

enum RouteDataFetcherKey: DependencyKey {
    static let liveValue: any RouteDataFetcherProtocol = RouteDataFetcher()
}

protocol RouteDataFetcherProtocol: DataFetcher {
    func fetchAll(districtID: District.ID, query: Query) async throws
    func fetch(routeID: Route.ID) async throws
    func update(_ route: Route, points: [Point], passages: [RoutePassage]) async throws
    func create(districtID: District.ID, route: Route, points: [Point], passages: [RoutePassage]) async throws
    func delete(_ routeID: Route.ID) async throws
}

struct RouteDataFetcher: RouteDataFetcherProtocol {

    @Dependency(HTTPClientKey.self) var client
    @Dependency(RouteStoreKey.self) var routeStore
    @Dependency(DistrictStoreKey.self) var districtStore
    @Dependency(PeriodStoreKey.self) var periodStore
    @Dependency(PointStoreKey.self) var pointStore
    @Dependency(PassageStoreKey.self) var passageStore
    @Dependency(\.defaultDatabase) var database

    func fetchAll(districtID: District.ID, query: Query) async throws {
        let token = try await getToken()
        let routes: [Route] = try await client.get(path: "/districts/\(districtID)/routes", query: query.queryItems, accessToken: token)
        try await syncAll(routes, districtId: districtID, query: query)
    }

    func fetch(routeID: Route.ID) async throws {
        let token = try await getToken()
        let pack: RoutePack = try await client.get(path: "/routes/\(routeID)", accessToken: token)
        try await syncPack(pack)
    }

    func update(_ route: Route, points: [Point], passages: [RoutePassage]) async throws {
        let token = try await getToken()
        let draft: RoutePack = .init(route: route, points: points, passages: passages)
        let pack: RoutePack = try await client.put(path: "/routes/\(route.id)", body: draft, accessToken: token)
        try await syncPack(pack)
    }

    func create(districtID: District.ID, route: Route, points: [Point], passages: [RoutePassage]) async throws {
        let token = try await getToken()
        let draft: RoutePack = .init(route: route, points: points, passages: passages)
        let pack: RoutePack = try await client.post(path: "/districts/\(districtID)/routes", body: draft, query: [:], accessToken: token)
        try await syncPack(pack)
    }

    func delete(_ routeID: Route.ID) async throws {
        let token = try await getToken()
        try await client.delete(path: "/routes/\(routeID)", query: [:], accessToken: token)
        try await database.write { db in
            try routeStore.deleteAll([routeID], from: db)
        }
    }

    private func syncPack(_ pack: RoutePack) async throws {
        let id = pack.route.id
        try await database.write { db in
            let oldPoints = try pointStore.fetchAll(where: { $0.routeId.eq(id) }, from: db)
            let oldPassages = try passageStore.fetchAll(where: { $0.routeId.eq(id) }, from: db)
            let (upsertedPoints, deletedPointIds) = oldPoints.diffById(with: pack.points)
            let (upsertedPassages, deletedPassageIds) = oldPassages.diffById(with: pack.passages)
            // delete
            try routeStore.upsert(pack.route, at: db)
            try pointStore.deleteAll(deletedPointIds, from: db)
            try passageStore.deleteAll(deletedPassageIds, from: db)
            // insert
            try pointStore.upsert(upsertedPoints, at: db)
            try passageStore.upsert(upsertedPassages, at: db)
        }
    }

    private func syncAll(_ routes: [Route], districtId: District.ID, query: Query) async throws {
        try await database.write { db in
            let oldRoutes = try routeStore.fetchAll(where: { $0.districtId.eq(districtId) }, from: db)
            let routesToReplace: [Route]
            if query == .all {
                routesToReplace = oldRoutes
            } else if let district = try districtStore.fetchAll(where: { $0.id.eq(districtId) }, from: db).first {
                let periods = try periodStore.fetchAll(
                    where: { $0.festivalId.eq(district.festivalId) },
                    from: db
                )
                let yearsToReplace: Set<Int>?
                switch query {
                case .all:
                    yearsToReplace = nil
                case .year(let requestedYear):
                    yearsToReplace = [requestedYear]
                case .latest:
                    let returnedPeriodIds = Set(routes.map(\.periodId))
                    let cachedPeriodIds = Set(periods.map(\.id))
                    if returnedPeriodIds.isEmpty {
                        yearsToReplace = periods.map(\.date.year).max().map { [$0] }
                    } else if returnedPeriodIds.isSubset(of: cachedPeriodIds) {
                        yearsToReplace = Set(
                            periods
                                .filter { returnedPeriodIds.contains($0.id) }
                                .map(\.date.year)
                        )
                    } else {
                        // A response referencing uncached periods cannot safely identify its year.
                        yearsToReplace = nil
                    }
                }
                if let yearsToReplace {
                    let periodIds = Set(
                        periods
                            .filter { yearsToReplace.contains($0.date.year) }
                            .map(\.id)
                    )
                    routesToReplace = oldRoutes.filter { periodIds.contains($0.periodId) }
                } else {
                    routesToReplace = []
                }
            } else {
                // Without the district's festival, a partial response cannot safely identify
                // which cached routes it is allowed to replace.
                routesToReplace = []
            }
            let (_, deletedRouteIds) = routesToReplace.diffById(with: routes)
            try routeStore.deleteAll(deletedRouteIds, from: db)
            try routeStore.upsert(routes, at: db)
        }
    }
}
