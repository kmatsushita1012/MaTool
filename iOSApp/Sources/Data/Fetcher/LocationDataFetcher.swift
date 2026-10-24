import Dependencies
import Shared

protocol LocationDataFetcherProtocol: DataFetcher {
    func fetchAll(festivalId: Festival.ID) async throws -> [FloatLocation]
    func fetch(districtId: District.ID) async throws -> FloatLocation?
    func update(_ location: FloatLocation) async throws -> FloatLocation
    func delete(districtId: District.ID) async throws
}

enum LocationDataFetcherKey: DependencyKey {
    static let liveValue: LocationDataFetcherProtocol = LocationDataFetcher()
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
