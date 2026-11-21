import Dependencies
import Shared

protocol EditionDataFetcherProtocol: DataFetcher {
    func fetchList(festivalID: Festival.ID) async throws -> EditionListResponse
    func create(festivalID: Festival.ID, year: Int) async throws -> EditionPack
    func fetch(festivalID: Festival.ID, year: Int) async throws -> EditionPack
    func update(_ pack: EditionPack) async throws -> EditionPack
    func activate(festivalID: Festival.ID, editionID: Edition.ID) async throws -> ActiveEdition
}

enum EditionDataFetcherKey: DependencyKey {
    static let liveValue: any EditionDataFetcherProtocol = EditionDataFetcher()
}

struct EditionDataFetcher: EditionDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) private var client

    func fetchList(festivalID: Festival.ID) async throws -> EditionListResponse {
        try await client.get(
            path: "/v1/festivals/\(festivalID)/editions",
            accessToken: await getToken()
        )
    }

    func create(festivalID: Festival.ID, year: Int) async throws -> EditionPack {
        try await client.post(
            path: "/v1/festivals/\(festivalID)/editions",
            body: EditionCreateForm(year: year),
            accessToken: await getToken()
        )
    }

    func fetch(festivalID: Festival.ID, year: Int) async throws -> EditionPack {
        try await client.get(
            path: "/v1/festivals/\(festivalID)/editions/\(year)",
            accessToken: await getToken()
        )
    }

    func update(_ pack: EditionPack) async throws -> EditionPack {
        try await client.put(
            path: "/v1/festivals/\(pack.edition.festivalId)/editions/\(pack.edition.year)",
            body: pack,
            accessToken: await getToken()
        )
    }

    func activate(festivalID: Festival.ID, editionID: Edition.ID) async throws -> ActiveEdition {
        try await client.put(
            path: "/v1/festivals/\(festivalID)/active-edition",
            body: ActiveEditionUpdateForm(editionId: editionID),
            accessToken: await getToken()
        )
    }
}
