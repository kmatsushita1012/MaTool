import Shared
import Testing
@testable import iOSApp

actor StoreCreditUsecaseSpy: StoreCreditUsecaseProtocol {
    private let products: [StoreCreditProduct]

    init(products: [StoreCreditProduct] = []) {
        self.products = products
    }

    func loadProducts() async throws -> [StoreCreditProduct] {
        products
    }

    func loadBalance(storeId: Store.ID) async throws -> CreditAccount {
        throw SpyInvocationError.unexpected("StoreCreditUsecase.loadBalance")
    }

    func loadHistory(storeId: Store.ID) async throws -> [PurchaseHistoryItem] {
        throw SpyInvocationError.unexpected("StoreCreditUsecase.loadHistory")
    }

    func purchase(store: Store, productId: String) async throws -> StoreCreditPurchaseResult {
        throw SpyInvocationError.unexpected("StoreCreditUsecase.purchase")
    }

    func restorePurchases(for store: Store) async throws -> Bool {
        throw SpyInvocationError.unexpected("StoreCreditUsecase.restorePurchases")
    }

    func recoverUnfinishedPurchases(for stores: [Store]) async {
        Issue.record("Unexpected StoreCreditUsecase.recoverUnfinishedPurchases call")
    }
}
