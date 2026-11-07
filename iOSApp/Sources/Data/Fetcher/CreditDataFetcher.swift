import Dependencies
import Shared

extension DependencyValues {
    var creditDataFetcher: any CreditDataFetcherProtocol {
        get { self[CreditDataFetcherKey.self] }
        set { self[CreditDataFetcherKey.self] = newValue }
    }
}

protocol CreditDataFetcherProtocol: DataFetcher {
    func fetchBalance(storeId: Store.ID) async throws -> CreditAccount
    func fetchHistory(storeId: Store.ID) async throws -> [PurchaseHistoryItem]
    func claim(storeId: Store.ID, signedTransactionInfo: String) async throws -> PurchaseResult
}

struct CreditDataFetcher: CreditDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) private var client

    func fetchBalance(storeId: Store.ID) async throws -> CreditAccount {
        try await client.get(path: "/stores/\(storeId)/credits", accessToken: await getToken(), isCache: false)
    }

    func fetchHistory(storeId: Store.ID) async throws -> [PurchaseHistoryItem] {
        try await client.get(path: "/stores/\(storeId)/purchases", accessToken: await getToken(), isCache: false)
    }

    func claim(storeId: Store.ID, signedTransactionInfo: String) async throws -> PurchaseResult {
        try await client.post(
            path: "/stores/\(storeId)/purchases",
            body: PurchaseClaimRequest(signedTransactionInfo: signedTransactionInfo),
            accessToken: await getToken()
        )
    }
}

enum CreditDataFetcherKey: DependencyKey {
    static let liveValue: any CreditDataFetcherProtocol = CreditDataFetcher()
}
