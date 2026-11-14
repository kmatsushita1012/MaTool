import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct PurchaseUsecaseTest {
    @Test("返金済み JWS の再送は Apple の現在状態を確認して Credit を付与しない")
    func claimRejectsTransactionRevokedAfterOriginalJWSWasIssued() async {
        let store = makeStore()
        let original = makePurchase(store: store)
        let refunded = makePurchase(store: store, revocationDate: Date(timeIntervalSince1970: 2_000))
        let stores = StoreRepositorySpy(store: store)
        let credits = CreditRepositorySpy(account: CreditAccount(storeId: store.id, balance: 0))
        let purchases = PurchaseRepositorySpy()
        let appStore = AppStoreClientSpy(purchase: original, current: refunded, notification: .init(
            notificationUUID: nil,
            type: .other,
            signedDate: Date(timeIntervalSince1970: 2_000),
            purchase: nil
        ))

        await #expect(throws: Error.conflict("Apple で購入取引が返金済み、または内容が一致しません。")) {
            try await withDependencies {
                $0[AdvertisingEnvironmentKey.self] = makeEnvironment()
                $0[StoreRepositoryKey.self] = stores
                $0[CreditRepositoryKey.self] = credits
                $0[PurchaseRepositoryKey.self] = purchases
                $0[AppStoreClientKey.self] = appStore
            } operation: {
                try await PurchaseUsecase().claim(
                    storeId: store.id,
                    signedTransactionInfo: "old-valid-jws",
                    user: .advertiser(store.ownerId)
                )
            }
        }

        #expect(await appStore.currentPurchaseCallCount == 1)
        #expect(await purchases.grantCalls.isEmpty)
    }

    @Test("返金されていない Credit 商品だけを現在状態照会後に付与する")
    func claimGrantsOnlyAfterCurrentAppleStatusIsVerified() async throws {
        let store = makeStore()
        let purchase = makePurchase(store: store)
        let stores = StoreRepositorySpy(store: store)
        let credits = CreditRepositorySpy(account: CreditAccount(storeId: store.id, balance: 10))
        let purchases = PurchaseRepositorySpy()
        let appStore = AppStoreClientSpy(purchase: purchase, notification: .init(
            notificationUUID: nil,
            type: .other,
            signedDate: Date(timeIntervalSince1970: 2_000),
            purchase: nil
        ))

        let result = try await withDependencies {
            $0[AdvertisingEnvironmentKey.self] = makeEnvironment()
            $0[StoreRepositoryKey.self] = stores
            $0[CreditRepositoryKey.self] = credits
            $0[PurchaseRepositoryKey.self] = purchases
            $0[AppStoreClientKey.self] = appStore
        } operation: {
            try await PurchaseUsecase().claim(
                storeId: store.id,
                signedTransactionInfo: "valid-jws",
                user: .advertiser(store.ownerId)
            )
        }

        #expect(result.creditedAmount == 500)
        #expect(result.balance == 510)
        #expect(await appStore.currentPurchaseCallCount == 1)
        #expect(await purchases.grantCalls.count == 1)
    }

    @Test("Credit 商品以外の REFUND 通知は台帳を書き換えない")
    func applyNotificationIgnoresNonCreditProducts() async throws {
        let store = makeStore()
        let otherProduct = makePurchase(store: store, productId: "unrelated-iap")
        let purchases = PurchaseRepositorySpy()
        let appStore = AppStoreClientSpy(purchase: otherProduct, notification: .init(
            notificationUUID: "notification-1",
            type: .refund,
            signedDate: Date(timeIntervalSince1970: 2_000),
            purchase: otherProduct
        ))

        try await withDependencies {
            $0[AdvertisingEnvironmentKey.self] = makeEnvironment()
            $0[PurchaseRepositoryKey.self] = purchases
            $0[AppStoreClientKey.self] = appStore
        } operation: {
            try await PurchaseUsecase().applyNotification(signedPayload: "valid-notification")
        }

        #expect(await purchases.refundMarkerCalls.isEmpty)
        #expect(await purchases.notificationCalls.isEmpty)
    }

    @Test("遅れて届いた古い REFUND は先に処理した REFUND_REVERSED を巻き戻さない")
    func ignoresOlderRefundAfterRefundReversed() async throws {
        let store = makeStore()
        let purchase = makePurchase(store: store)
        let firstRefundDate = Date(timeIntervalSince1970: 1_000)
        let reversalDate = Date(timeIntervalSince1970: 2_000)
        let record = PurchaseRecord(
            transactionId: purchase.transactionId,
            storeId: store.id,
            appAccountToken: store.purchaseAccountToken,
            productId: purchase.productId,
            creditedAmount: 500,
            purchasedAt: purchase.purchasedAt,
            environment: purchase.environment,
            creditGranted: true,
            refundStatus: .refunded,
            refundDeductedCredits: 500,
            lastRefundEventSignedDate: firstRefundDate,
            refundedAt: firstRefundDate
        )
        let purchases = PurchaseRepositorySpy(records: [record])
        let credits = CreditRepositorySpy(account: CreditAccount(storeId: store.id, balance: 0))
        let appStore = AppStoreClientSpy(purchase: purchase, notification: .init(
            notificationUUID: "reversal",
            type: .refundReversed,
            signedDate: reversalDate,
            purchase: purchase
        ))

        try await withDependencies {
            $0[AdvertisingEnvironmentKey.self] = makeEnvironment()
            $0[PurchaseRepositoryKey.self] = purchases
            $0[CreditRepositoryKey.self] = credits
            $0[AppStoreClientKey.self] = appStore
        } operation: {
            let usecase = PurchaseUsecase()
            try await usecase.applyNotification(signedPayload: "reversal")
            await appStore.setNotification(.init(
                notificationUUID: "old-refund",
                type: .refund,
                signedDate: firstRefundDate,
                purchase: purchase
            ))
            try await usecase.applyNotification(signedPayload: "old-refund")
        }

        let stored = try #require(await purchases.get(transactionId: purchase.transactionId))
        #expect(stored.refundStatus == .active)
        #expect(stored.refundDeductedCredits == 0)
        #expect(stored.lastRefundEventSignedDate == reversalDate)
        #expect(await purchases.notificationCalls.count == 1)
    }

    @Test("未付与の REFUND_REVERSED マーカーは古い REFUND を無視し、後続 Claim を一度だけ許可する")
    func reversalMarkerIgnoresOlderRefundAndAllowsOneClaim() async throws {
        let store = makeStore()
        let purchase = makePurchase(store: store)
        let oldRefundDate = Date(timeIntervalSince1970: 1_000)
        let reversalDate = Date(timeIntervalSince1970: 2_000)
        let purchases = PurchaseRepositorySpy()
        let credits = CreditRepositorySpy(account: CreditAccount(storeId: store.id, balance: 0))
        let appStore = AppStoreClientSpy(purchase: purchase, notification: .init(
            notificationUUID: "reversal",
            type: .refundReversed,
            signedDate: reversalDate,
            purchase: purchase
        ))

        try await withDependencies {
            $0[AdvertisingEnvironmentKey.self] = makeEnvironment()
            $0[StoreRepositoryKey.self] = StoreRepositorySpy(store: store)
            $0[CreditRepositoryKey.self] = credits
            $0[PurchaseRepositoryKey.self] = purchases
            $0[AppStoreClientKey.self] = appStore
        } operation: {
            let usecase = PurchaseUsecase()
            try await usecase.applyNotification(signedPayload: "reversal")
            await appStore.setNotification(.init(
                notificationUUID: "old-refund",
                type: .refund,
                signedDate: oldRefundDate,
                purchase: purchase
            ))
            try await usecase.applyNotification(signedPayload: "old-refund")
            _ = try await usecase.claim(
                storeId: store.id,
                signedTransactionInfo: "reissued-valid-jws",
                user: .advertiser(store.ownerId)
            )
        }

        let stored = try #require(await purchases.get(transactionId: purchase.transactionId))
        #expect(await purchases.refundMarkerCalls.count == 1)
        #expect(await purchases.grantCalls.count == 1)
        #expect(stored.creditGranted)
        #expect(stored.refundStatus == .active)
        #expect(stored.lastRefundEventSignedDate == reversalDate)
    }
    @Test("広告主が自分の店舗の残高を取得するとCreditAccountを返す")
    func creditsReturnsOwnedStoreBalance() async throws {
        let store = makeStore()
        let account = CreditAccount(storeId: store.id, balance: 42)
        let result = try await withDependencies {
            $0[StoreRepositoryKey.self] = StoreRepositorySpy(store: store)
            $0[CreditRepositoryKey.self] = CreditRepositorySpy(account: account)
        } operation: {
            try await PurchaseUsecase().credits(storeId: store.id, user: .advertiser(store.ownerId))
        }
        #expect(result.balance == 42)
        #expect(result.storeId == store.id)
    }

    @Test("存在しないCredit残高はゼロと捏造せずnotFoundを返す")
    func creditsRequiresExistingAccount() async {
        let store = makeStore()
        await #expect(throws: Error.notFound("Credit 残高が見つかりません。")) {
            try await withDependencies {
                $0[StoreRepositoryKey.self] = StoreRepositorySpy(store: store)
                $0[CreditRepositoryKey.self] = CreditRepositorySpy()
            } operation: {
                try await PurchaseUsecase().credits(storeId: store.id, user: .advertiser(store.ownerId))
            }
        }
    }

    @Test("所有者以外には購入履歴を開示せず、本人なら履歴取得を許可する")
    func historyChecksOwnerBeforeFetching() async throws {
        let store = makeStore()
        let repository = StoreRepositorySpy(store: store)
        let purchases = PurchaseRepositorySpy()

        await #expect(throws: Error.notFound("指定された店舗が見つかりません。")) {
            try await withDependencies {
                $0[StoreRepositoryKey.self] = repository
                $0[PurchaseRepositoryKey.self] = purchases
            } operation: {
                try await PurchaseUsecase().history(storeId: store.id, user: .advertiser("other-owner"))
            }
        }

        let history = try await withDependencies {
            $0[StoreRepositoryKey.self] = repository
            $0[PurchaseRepositoryKey.self] = purchases
        } operation: {
            try await PurchaseUsecase().history(storeId: store.id, user: .advertiser(store.ownerId))
        }
        #expect(history.isEmpty)
    }


    @Test("存在しない店舗への購入確定はApple検証を呼び出す前に拒否する")
    func claimRequiresOwnedStore() async {
        await #expect(throws: Error.notFound("指定された店舗が見つかりません。")) {
            try await withDependencies {
                $0[StoreRepositoryKey.self] = StoreRepositorySpy()
            } operation: {
                try await PurchaseUsecase().claim(
                    storeId: "missing",
                    signedTransactionInfo: "not-verified",
                    user: .advertiser("owner-1")
                )
            }
        }
    }

    @Test("Apple購入のAppAccountTokenが店舗と不一致ならCreditを付与しない")
    func claimRejectsAnotherStoreToken() async {
        let store = makeStore()
        let valid = makePurchase(store: store)
        let foreign = VerifiedPurchase(
            transactionId: valid.transactionId,
            appAccountToken: UUID(),
            productId: valid.productId,
            purchasedAt: valid.purchasedAt,
            environment: valid.environment,
            revocationDate: nil,
            isConsumable: true
        )
        let purchases = PurchaseRepositorySpy()
        let appStore = AppStoreClientSpy(purchase: foreign, notification: .init(
            notificationUUID: nil, type: .other,
            signedDate: Date(timeIntervalSince1970: 2_000), purchase: nil
        ))
        await #expect(throws: Error.forbidden("購入取引と店舗の購入 token が一致しません。")) {
            try await withDependencies {
                $0[StoreRepositoryKey.self] = StoreRepositorySpy(store: store)
                $0[AppStoreClientKey.self] = appStore
                $0[PurchaseRepositoryKey.self] = purchases
            } operation: {
                try await PurchaseUsecase().claim(
                    storeId: store.id,
                    signedTransactionInfo: "foreign-jws",
                    user: .advertiser(store.ownerId)
                )
            }
        }
        #expect(await purchases.grantCalls.isEmpty)
    }

    @Test("設定外の商品IDは購入検証後でもCreditの付与対象にしない")
    func claimRejectsUnconfiguredProduct() async {
        let store = makeStore()
        let purchase = makePurchase(store: store, productId: "unrelated-product")
        let purchases = PurchaseRepositorySpy()
        let appStore = AppStoreClientSpy(purchase: purchase, notification: .init(
            notificationUUID: nil, type: .other,
            signedDate: Date(timeIntervalSince1970: 2_000), purchase: nil
        ))
        await #expect(throws: Error.badRequest("対象外の商品または環境の取引です。")) {
            try await withDependencies {
                $0[AdvertisingEnvironmentKey.self] = makeEnvironment()
                $0[StoreRepositoryKey.self] = StoreRepositorySpy(store: store)
                $0[PurchaseRepositoryKey.self] = purchases
                $0[AppStoreClientKey.self] = appStore
            } operation: {
                try await PurchaseUsecase().claim(
                    storeId: store.id,
                    signedTransactionInfo: "unrelated-jws",
                    user: .advertiser(store.ownerId)
                )
            }
        }
        #expect(await purchases.grantCalls.isEmpty)
        #expect(await appStore.currentPurchaseCallCount == 0)
    }

    @Test("未ログイン・管理者権限では購入Creditにアクセスできない")
    func rejectsNonAdvertiserCreditRequests() async {
        let store = makeStore()
        await #expect(throws: Error.unauthorized("広告主としてログインしてください。")) {
            try await PurchaseUsecase().credits(storeId: store.id, user: .guest)
        }
        await #expect(throws: Error.forbidden("広告主としてログインしてください。")) {
            try await PurchaseUsecase().credits(storeId: store.id, user: .district("district-1"))
        }
    }

}

private func makeEnvironment() -> AdvertisingEnvironment {
    AdvertisingEnvironment(environment: [
        "APP_STORE_ENVIRONMENT": "sandbox",
        "STORE_CREDIT_PRODUCT_ID_500": "credit-500"
    ])
}

private func makeStore() -> Store {
    Store(
        id: "store-1",
        festivalId: "festival-1",
        ownerId: "advertiser-1",
        purchaseAccountToken: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Store",
        address: "Address",
        coordinate: Coordinate(latitude: 35, longitude: 139),
        businessHours: ""
    )
}

private func makePurchase(store: Store, productId: String = "credit-500", revocationDate: Date? = nil) -> VerifiedPurchase {
    VerifiedPurchase(
        transactionId: "transaction-1",
        appAccountToken: store.purchaseAccountToken,
        productId: productId,
        purchasedAt: Date(timeIntervalSince1970: 500),
        environment: "Sandbox",
        revocationDate: revocationDate,
        isConsumable: true
    )
}
