import Dependencies
import Shared

protocol DataFetcher: Sendable {}

extension DataFetcher {
    func getToken() async -> String? {
        @Dependency(AuthServiceKey.self) var authService
        return await authService.getAccessToken()
    }
}

enum Query: Sendable, Equatable {
    case all
    case year(Int)
    case latest

    var queryItems: [String: Any] {
        switch self {
        case .all:
            [:]
        case .year(let year):
            ["year": year]
        case .latest:
            ["year": "latest"]
        }
    }
}

protocol SceneDataFetcherProtocol: DataFetcher {
    func launchFestival(festivalId: Festival.ID) async throws -> LaunchFestivalPack
    func launchFestival(districtId: District.ID) async throws -> LaunchFestivalPack
    func launchDistrict(districtId: District.ID, periodId: Period.ID?) async throws -> LaunchDistrictPack
}

extension SceneDataFetcherProtocol {
    func launchDistrict(districtId: District.ID) async throws -> LaunchDistrictPack {
        try await launchDistrict(districtId: districtId, periodId: nil)
    }
}

protocol FestivalDataFetcherProtocol: DataFetcher {
    func update(festival: Festival, checkPoints: [Checkpoint], hazardSections: [HazardSection]) async throws -> FestivalPack
    func fetchAll() async throws -> [Festival]
    func fetch(festivalID: Festival.ID) async throws -> FestivalPack
}

protocol DistrictDataFetcherProtocol: DataFetcher {
    func create(name: String, email: String, festivalId: String) async throws -> DistrictPack
    func reissue(districtId: District.ID, email: String) async throws -> DistrictPack
    func update(district: District, performances: [Performance]) async throws -> DistrictPack
    func update(district: District) async throws -> District
    func fetchAll(festivalID: Festival.ID) async throws -> [District]
    func fetch(districtID: District.ID) async throws -> DistrictPack
}

protocol RouteDataFetcherProtocol: DataFetcher {
    func fetchAll(districtID: District.ID, query: Query) async throws -> [Route]
    func fetch(routeID: Route.ID) async throws -> RoutePack
    func update(_ route: Route, points: [Point], passages: [RoutePassage]) async throws -> RoutePack
    func create(districtID: District.ID, route: Route, points: [Point], passages: [RoutePassage]) async throws -> RoutePack
    func delete(_ routeID: Route.ID) async throws
}

protocol PeriodDataFetcherProtocol: DataFetcher {
    func fetchAll(festivalID: Festival.ID, query: Query) async throws -> [Period]
    func fetch(_ id: Period.ID) async throws -> Period
    func update(_ period: Period) async throws -> Period
    func create(_ period: Period) async throws -> Period
    func delete(_ id: Period.ID) async throws
}

protocol LocationDataFetcherProtocol: DataFetcher {
    func fetchAll(festivalId: Festival.ID) async throws -> [FloatLocation]
    func fetch(districtId: District.ID) async throws -> FloatLocation?
    func update(_ location: FloatLocation) async throws -> FloatLocation
    func delete(districtId: District.ID) async throws
}

enum SceneDataFetcherKey: DependencyKey {
    static let liveValue: SceneDataFetcherProtocol = SceneDataFetcher()
}

enum FestivalDataFetcherKey: DependencyKey {
    static let liveValue: FestivalDataFetcherProtocol = FestivalDataFetcher()
}

enum DistrictDataFetcherKey: DependencyKey {
    static let liveValue: DistrictDataFetcherProtocol = DistrictDataFetcher()
}

enum RouteDataFetcherKey: DependencyKey {
    static let liveValue: RouteDataFetcherProtocol = RouteDataFetcher()
}

enum PeriodDataFetcherKey: DependencyKey {
    static let liveValue: PeriodDataFetcherProtocol = PeriodDataFetcher()
}

enum LocationDataFetcherKey: DependencyKey {
    static let liveValue: LocationDataFetcherProtocol = LocationDataFetcher()
}

struct SceneDataFetcher: SceneDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) var client

    func launchFestival(festivalId: Festival.ID) async throws -> LaunchFestivalPack {
        try await fetchFestivalPack(path: "/festivals/\(festivalId)/launch")
    }

    func launchFestival(districtId: District.ID) async throws -> LaunchFestivalPack {
        try await fetchFestivalPack(path: "/districts/\(districtId)/launch-festival")
    }

    private func fetchFestivalPack(path: String) async throws -> LaunchFestivalPack {
        try await client.get(path: path, accessToken: await getToken(), isCache: false)
    }

    func launchDistrict(districtId: District.ID, periodId: Period.ID?) async throws -> LaunchDistrictPack {
        let query = periodId.map { ["periodId": $0] } ?? [:]
        return try await client.get(
            path: "/districts/\(districtId)/launch",
            query: query,
            accessToken: await getToken(),
            isCache: false
        )
    }
}

struct FestivalDataFetcher: FestivalDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) var client

    func update(festival: Festival, checkPoints: [Checkpoint], hazardSections: [HazardSection]) async throws -> FestivalPack {
        let pack = FestivalPack(festival: festival, checkpoints: checkPoints, hazardSections: hazardSections)
        return try await client.put(path: "/festivals/\(festival.id)", body: pack, accessToken: await getToken())
    }

    func fetchAll() async throws -> [Festival] {
        try await client.get(path: "/festivals")
    }

    func fetch(festivalID: Festival.ID) async throws -> FestivalPack {
        try await client.get(path: "/festivals/\(festivalID)")
    }
}

struct DistrictDataFetcher: DistrictDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) var client

    func create(name: String, email: String, festivalId: String) async throws -> DistrictPack {
        let form = DistrictCreateForm(name: name, email: email)
        return try await client.post(
            path: "/festivals/\(festivalId)/districts",
            body: form,
            accessToken: await getToken()
        )
    }

    func reissue(districtId: District.ID, email: String) async throws -> DistrictPack {
        let form = DistrictReissueForm(email: email)
        return try await client.post(
            path: "/districts/\(districtId)/reissue",
            body: form,
            accessToken: await getToken()
        )
    }

    func update(district: District, performances: [Performance]) async throws -> DistrictPack {
        let pack = DistrictPack(district: district, performances: performances)
        return try await client.put(path: "/districts/\(district.id)", body: pack, accessToken: await getToken())
    }

    func update(district: District) async throws -> District {
        try await client.put(path: "/districts/\(district.id)/core", body: district, accessToken: await getToken())
    }

    func fetchAll(festivalID: Festival.ID) async throws -> [District] {
        try await client.get(path: "/festivals/\(festivalID)/districts")
    }

    func fetch(districtID: District.ID) async throws -> DistrictPack {
        try await client.get(path: "/districts/\(districtID)")
    }
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

struct PeriodDataFetcher: PeriodDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) var client

    func fetchAll(festivalID: Festival.ID, query: Query) async throws -> [Period] {
        try await client.get(path: "/festivals/\(festivalID)/periods", query: query.queryItems)
    }

    func fetch(_ id: Period.ID) async throws -> Period {
        try await client.get(path: "/periods/\(id)")
    }

    func update(_ period: Period) async throws -> Period {
        try await client.put(path: "/periods/\(period.id)", body: period, accessToken: await getToken())
    }

    func create(_ period: Period) async throws -> Period {
        try await client.post(path: "/festivals/\(period.festivalId)/periods", body: period, accessToken: await getToken())
    }

    func delete(_ id: Period.ID) async throws {
        try await client.delete(path: "/periods/\(id)", accessToken: await getToken())
    }
}

struct LocationDataFetcher: LocationDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) var client

    func fetchAll(festivalId: Festival.ID) async throws -> [FloatLocation] {
        try await client.get(path: "/festivals/\(festivalId)/locations", accessToken: await getToken(), isCache: false)
    }

    func fetch(districtId: District.ID) async throws -> FloatLocation? {
        try await client.get(path: "/districts/\(districtId)/locations", accessToken: await getToken(), isCache: false)
    }

    func update(_ location: FloatLocation) async throws -> FloatLocation {
        try await client.put(
            path: "/districts/\(location.districtId)/locations",
            body: location,
            accessToken: await getToken()
        )
    }

    func delete(districtId: District.ID) async throws {
        try await client.delete(path: "/districts/\(districtId)/locations", accessToken: await getToken())
    }
}
