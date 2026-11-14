import Dependencies
import Shared

extension DependencyValues {
    var advertiserStoreUsecase: any AdvertiserStoreUsecaseProtocol {
        get { self[AdvertiserStoreUsecaseKey.self] }
        set { self[AdvertiserStoreUsecaseKey.self] = newValue }
    }
}

protocol AdvertiserStoreUsecaseProtocol: Sendable {
    func loadOwnedStores() async throws -> [Store]
    func create(festivalId: Festival.ID, name: String, address: String?, coordinate: Coordinate?, businessHours: String, description: String?) async throws -> Store
    func save(_ store: Store) async throws -> Store
}

struct AdvertiserStoreUsecase: AdvertiserStoreUsecaseProtocol {
    @Dependency(StoreDataFetcherKey.self) private var dataFetcher

    func loadOwnedStores() async throws -> [Store] {
        try await dataFetcher.fetchOwnedStores()
    }

    func create(
        festivalId: Festival.ID,
        name: String,
        address: String?,
        coordinate: Coordinate?,
        businessHours: String,
        description: String?
    ) async throws -> Store {
        try await dataFetcher.create(
            festivalId: festivalId,
            request: StoreCreateRequest(
                name: name,
                address: address,
                coordinate: coordinate,
                businessHours: businessHours,
                description: description
            )
        )
    }

    func save(_ store: Store) async throws -> Store {
        try await dataFetcher.update(store)
    }
}

enum AdvertiserStoreUsecaseKey: DependencyKey {
    static let liveValue: any AdvertiserStoreUsecaseProtocol = AdvertiserStoreUsecase()
}
