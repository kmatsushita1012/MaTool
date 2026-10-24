import Dependencies
import Shared

protocol FestivalDataFetcherProtocol: DataFetcher {
    func update(festival: Festival, checkPoints: [Checkpoint], hazardSections: [HazardSection]) async throws -> FestivalPack
    func fetchAll() async throws -> [Festival]
    func fetch(festivalID: Festival.ID) async throws -> FestivalPack
}

enum FestivalDataFetcherKey: DependencyKey {
    static let liveValue: FestivalDataFetcherProtocol = FestivalDataFetcher()
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
