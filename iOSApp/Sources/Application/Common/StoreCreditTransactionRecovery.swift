import Shared

func recoverUnfinishedStoreCreditPurchases(
    for stores: [Store],
    storeKitClient: any StoreKitClientProtocol,
    creditDataFetcher: any CreditDataFetcherProtocol
) async {
    let transactions = await storeKitClient.unfinishedTransactions()
    for transaction in transactions {
        guard let appAccountToken = transaction.appAccountToken,
              let store = stores.first(where: { $0.purchaseAccountToken == appAccountToken }) else {
            continue
        }
        do {
            _ = try await creditDataFetcher.claim(
                storeId: store.id,
                signedTransactionInfo: transaction.signedTransactionInfo
            )
            await storeKitClient.finish(transactionId: transaction.transactionId)
        } catch {
            // Keep the StoreKit transaction unfinished so a later app session can retry it.
        }
    }
}
