import Dependencies
import Shared

extension DependencyValues {
    var storeDataFetcher: any StoreDataFetcherProtocol {
        get { self[StoreDataFetcherKey.self] }
        set { self[StoreDataFetcherKey.self] = newValue }
    }
}

protocol StoreDataFetcherProtocol: DataFetcher {
    func fetchOwnedStores() async throws -> [Store]
    func create(festivalId: Festival.ID, request: StoreCreateRequest) async throws -> Store
    func update(_ store: Store) async throws -> Store
}

struct StoreDataFetcher: StoreDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) private var client

    func fetchOwnedStores() async throws -> [Store] {
        try await client.get(path: "/advertisers/me/stores", accessToken: try await getRequiredToken(), isCache: false)
    }

    func create(festivalId: Festival.ID, request: StoreCreateRequest) async throws -> Store {
        try await client.post(
            path: "/festivals/\(festivalId)/stores",
            body: request,
            accessToken: try await getRequiredToken()
        )
    }

    func update(_ store: Store) async throws -> Store {
        try await client.put(path: "/stores/\(store.id)", body: store, accessToken: try await getRequiredToken())
    }
}

enum StoreDataFetcherKey: DependencyKey {
    static let liveValue: any StoreDataFetcherProtocol = StoreDataFetcher()
}
