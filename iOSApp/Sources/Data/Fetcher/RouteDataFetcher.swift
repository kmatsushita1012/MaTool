import Dependencies
import Shared

protocol RouteDataFetcherProtocol: DataFetcher {
    func fetchAll(districtID: District.ID, query: Query) async throws -> [Route]
    func fetch(routeID: Route.ID) async throws -> RoutePack
    func update(_ route: Route, points: [Point], passages: [RoutePassage]) async throws -> RoutePack
    func create(districtID: District.ID, route: Route, points: [Point], passages: [RoutePassage]) async throws -> RoutePack
    func delete(_ routeID: Route.ID) async throws
}

enum RouteDataFetcherKey: DependencyKey {
    static let liveValue: RouteDataFetcherProtocol = RouteDataFetcher()
}

struct RouteDataFetcher: RouteDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) var client

    func fetchAll(districtID: District.ID, query: Query) async throws -> [Route] {
        try await client.get(path: "/districts/\(districtID)/routes", query: query.queryItems, accessToken: await getToken())
    }

    func fetch(routeID: Route.ID) async throws -> RoutePack {
        try await client.get(path: "/routes/\(routeID)", accessToken: await getToken())
    }

    func update(_ route: Route, points: [Point], passages: [RoutePassage]) async throws -> RoutePack {
        let pack = RoutePack(route: route, points: points, passages: passages)
        return try await client.put(path: "/routes/\(route.id)", body: pack, accessToken: await getToken())
    }

    func create(districtID: District.ID, route: Route, points: [Point], passages: [RoutePassage]) async throws -> RoutePack {
        let pack = RoutePack(route: route, points: points, passages: passages)
        return try await client.post(
            path: "/districts/\(districtID)/routes",
            body: pack,
            accessToken: await getToken()
        )
    }

    func delete(_ routeID: Route.ID) async throws {
        try await client.delete(path: "/routes/\(routeID)", accessToken: await getToken())
    }
}
