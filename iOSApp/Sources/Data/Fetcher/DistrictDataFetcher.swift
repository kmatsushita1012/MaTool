import Dependencies
import Shared

protocol DistrictDataFetcherProtocol: DataFetcher {
    func create(name: String, email: String, festivalId: String) async throws -> DistrictPack
    func reissue(districtId: District.ID, email: String) async throws -> DistrictPack
    func update(district: District, performances: [Performance]) async throws -> DistrictPack
    func update(district: District) async throws -> District
    func fetchAll(festivalID: Festival.ID) async throws -> [District]
    func fetch(districtID: District.ID) async throws -> DistrictPack
}

enum DistrictDataFetcherKey: DependencyKey {
    static let liveValue: DistrictDataFetcherProtocol = DistrictDataFetcher()
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
