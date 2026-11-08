import Dependencies
import Shared

struct AdvertiserDashboardPreparation: Equatable {
    let stores: AppResult<[Store]>
    let festivals: AppResult<[Festival]>
}

protocol AdvertiserDashboardUsecaseProtocol: Sendable {
    func callAsFunction() async -> AdvertiserDashboardPreparation
}

struct AdvertiserDashboardUsecase: AdvertiserDashboardUsecaseProtocol {
    @Dependency(StoreDataFetcherKey.self) private var storeDataFetcher
    @Dependency(FestivalDataFetcherKey.self) private var festivalDataFetcher
    @Dependency(\.storeCreditTransactionRecovery) private var storeCreditTransactionRecovery

    func callAsFunction() async -> AdvertiserDashboardPreparation {
        async let storesTask: AppResult<[Store]> = task {
            try await storeDataFetcher.fetchOwnedStores()
        }
        async let festivalsTask: AppResult<[Festival]> = task {
            try await festivalDataFetcher.fetchAll()
        }
        let (stores, festivals) = await (storesTask, festivalsTask)

        if case .success(let stores) = stores {
            await storeCreditTransactionRecovery.recoverUnfinishedPurchases(for: stores)
        }

        return AdvertiserDashboardPreparation(stores: stores, festivals: festivals)
    }
}

extension DependencyValues {
    var advertiserDashboardUsecase: any AdvertiserDashboardUsecaseProtocol {
        get { self[AdvertiserDashboardUsecaseKey.self] }
        set { self[AdvertiserDashboardUsecaseKey.self] = newValue }
    }
}

enum AdvertiserDashboardUsecaseKey: DependencyKey {
    static let liveValue: any AdvertiserDashboardUsecaseProtocol = AdvertiserDashboardUsecase()
}
