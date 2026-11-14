import Dependencies
import Shared

extension DependencyValues {
    var storeCreditUsecase: any StoreCreditUsecaseProtocol {
        get { self[StoreCreditUsecaseKey.self] }
        set { self[StoreCreditUsecaseKey.self] = newValue }
    }
}

enum StoreCreditPurchaseResult: Equatable, Sendable {
    case completed(PurchaseResult)
    case pending
    case cancelled
}

struct StoreCreditProductCatalog: Equatable, Sendable {
    var products: [StoreCreditProduct] = []
    var errorMessage: String?
    var isLoading = false
    var hasAttemptedLoad = false
}

protocol StoreCreditUsecaseProtocol: Sendable {
    func loadProducts() async throws -> [StoreCreditProduct]
    func loadBalance(storeId: Store.ID) async throws -> CreditAccount
    func loadHistory(storeId: Store.ID) async throws -> [PurchaseHistoryItem]
    func purchase(store: Store, productId: String) async throws -> StoreCreditPurchaseResult
    func restorePurchases(for store: Store) async throws -> Bool
    func recoverUnfinishedPurchases(for stores: [Store]) async
}

struct StoreCreditUsecase: StoreCreditUsecaseProtocol {
    @Dependency(CreditDataFetcherKey.self) private var dataFetcher
    @Dependency(\.storeKitClient) private var storeKitClient

    func loadProducts() async throws -> [StoreCreditProduct] {
        try await storeKitClient.products()
    }

    func loadBalance(storeId: Store.ID) async throws -> CreditAccount {
        try await dataFetcher.fetchBalance(storeId: storeId)
    }

    func loadHistory(storeId: Store.ID) async throws -> [PurchaseHistoryItem] {
        try await dataFetcher.fetchHistory(storeId: storeId)
    }

    func purchase(store: Store, productId: String) async throws -> StoreCreditPurchaseResult {
        switch try await storeKitClient.purchase(productId: productId, appAccountToken: store.purchaseAccountToken) {
        case .cancelled:
            return .cancelled
        case .pending:
            return .pending
        case .purchased(let transaction):
            let result = try await dataFetcher.claim(
                storeId: store.id,
                signedTransactionInfo: transaction.signedTransactionInfo
            )
            await storeKitClient.finish(transactionId: transaction.transactionId)
            return .completed(result)
        }
    }

    func restorePurchases(for store: Store) async throws -> Bool {
        guard try await storeKitClient.synchronizePurchases() else { return false }
        await recoverUnfinishedStoreCreditPurchases(
            for: [store],
            storeKitClient: storeKitClient,
            creditDataFetcher: dataFetcher
        )
        return true
    }

    func recoverUnfinishedPurchases(for stores: [Store]) async {
        await recoverUnfinishedStoreCreditPurchases(
            for: stores,
            storeKitClient: storeKitClient,
            creditDataFetcher: dataFetcher
        )
    }
}

enum StoreCreditUsecaseKey: DependencyKey {
    static let liveValue: any StoreCreditUsecaseProtocol = StoreCreditUsecase()
}
