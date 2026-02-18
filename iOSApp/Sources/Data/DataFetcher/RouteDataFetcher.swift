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
    @Dependency(PointStoreKey.self) var pointStore
    @Dependency(PassageStoreKey.self) var passageStore
    @Dependency(\.defaultDatabase) var database

    func fetchAll(districtID: District.ID, query: Query) async throws {
        let path = "/districts/\(districtID)/routes"
        let routes: [Route] = try await client.get(path: path, query: query.queryItems)
        try await syncAll(routes)
    }

    func fetch(routeID: Route.ID) async throws {
        let pack: RoutePack = try await client.get(path: "/routes/\(routeID)")
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
            let oldPoints = try pointStore.fetchAll(where: { $0.routeId == id }, from: db)
            let oldPassages = try passageStore.fetchAll(where: { $0.routeId == id }, from: db)
            let (insertedPoints, deletedPointIds) = oldPoints.diff(with: pack.points)
            let (insertedPassages, deletedPassageIds) = oldPassages.diff(with: pack.passages)
            // delete
            try routeStore.delete(pack.route.id, from: db)
            try pointStore.deleteAll(deletedPointIds, from: db)
            try passageStore.deleteAll(deletedPassageIds, from: db)
            // insert
            try routeStore.insert(pack.route, at: db)
            try pointStore.insert(insertedPoints, at: db)
            try passageStore.insert(insertedPassages, at: db)
        }
    }

    private func syncAll(_ routes: [Route]) async throws {
        try await database.write { db in
            try routeStore.insert(routes, at: db)
        }
    }
}
