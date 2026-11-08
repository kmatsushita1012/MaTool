import Dependencies
import Shared

extension DependencyValues {
    var storeCreditTransactionRecovery: any StoreCreditTransactionRecoveryProtocol {
        get { self[StoreCreditTransactionRecoveryKey.self] }
        set { self[StoreCreditTransactionRecoveryKey.self] = newValue }
    }
}

protocol StoreCreditTransactionRecoveryProtocol: Sendable {
    func recoverUnfinishedPurchases(for stores: [Store]) async
}

struct StoreCreditTransactionRecovery: StoreCreditTransactionRecoveryProtocol {
    @Dependency(\.storeKitClient) private var storeKitClient
    @Dependency(CreditDataFetcherKey.self) private var dataFetcher

    func recoverUnfinishedPurchases(for stores: [Store]) async {
        let transactions = await storeKitClient.unfinishedTransactions()
        for transaction in transactions {
            guard let appAccountToken = transaction.appAccountToken,
                  let store = stores.first(where: { $0.purchaseAccountToken == appAccountToken }) else {
                continue
            }
            do {
                _ = try await dataFetcher.claim(
                    storeId: store.id,
                    signedTransactionInfo: transaction.signedTransactionInfo
                )
                await storeKitClient.finish(transactionId: transaction.transactionId)
            } catch {
                // Keep the StoreKit transaction unfinished so a later app session can retry it.
            }
        }
    }
}

enum StoreCreditTransactionRecoveryKey: DependencyKey {
    static let liveValue: any StoreCreditTransactionRecoveryProtocol = StoreCreditTransactionRecovery()
}
