import Dependencies
import Foundation
import Shared

enum PurchaseUsecaseKey: DependencyKey {
    static let liveValue: any PurchaseUsecaseProtocol = PurchaseUsecase()
}

protocol PurchaseUsecaseProtocol: Sendable {
    func credits(storeId: Store.ID, user: UserRole) async throws -> CreditAccount
    func history(storeId: Store.ID, user: UserRole) async throws -> [PurchaseHistoryItem]
    func claim(storeId: Store.ID, signedTransactionInfo: String, user: UserRole) async throws -> PurchaseResult
    func applyNotification(signedPayload: String) async throws
}

struct PurchaseUsecase: PurchaseUsecaseProtocol {
    @Dependency(StoreRepositoryKey.self) var stores
    @Dependency(CreditRepositoryKey.self) var creditsRepository
    @Dependency(PurchaseRepositoryKey.self) var purchases
    @Dependency(AppStoreClientKey.self) var appStore

    func credits(storeId: Store.ID, user: UserRole) async throws -> CreditAccount {
        let ownerId = try advertiserId(user)
        guard try await stores.getOwned(id: storeId, ownerId: ownerId) != nil else { throw Error.notFound("指定された店舗が見つかりません。") }
        guard let account = try await creditsRepository.get(storeId: storeId) else { throw Error.notFound("Credit 残高が見つかりません。") }
        return account
    }

    func history(storeId: Store.ID, user: UserRole) async throws -> [PurchaseHistoryItem] {
        let ownerId = try advertiserId(user)
        guard try await stores.getOwned(id: storeId, ownerId: ownerId) != nil else { throw Error.notFound("指定された店舗が見つかりません。") }
        return try await purchases.history(storeId: storeId)
    }

    func claim(storeId: Store.ID, signedTransactionInfo: String, user: UserRole) async throws -> PurchaseResult {
        let ownerId = try advertiserId(user)
        guard let store = try await stores.getOwned(id: storeId, ownerId: ownerId) else { throw Error.notFound("指定された店舗が見つかりません。") }
        let verified = try await appStore.verifyPurchase(signedTransactionInfo: signedTransactionInfo)
        guard verified.appAccountToken == store.purchaseAccountToken else {
            throw Error.forbidden("購入取引と店舗の購入 token が一致しません。")
        }
        let config = AdvertisingEnvironment()
        guard verified.environment == config.appStoreEnvironment.rawValue,
              let amount = config.productCredits[verified.productId] else {
            throw Error.badRequest("対象外の商品または環境の取引です。")
        }

        for _ in 0..<5 {
            let old = try await purchases.get(transactionId: verified.transactionId)
            if let old {
                try validate(old, matches: verified, store: store)
                if old.creditGranted {
                    guard let account = try await creditsRepository.get(storeId: storeId) else { throw Error.notFound("Credit 残高が見つかりません。") }
                    return PurchaseResult(transactionId: old.transactionId, creditedAmount: old.creditedAmount, balance: account.balance)
                }
                guard old.refundStatus == .active else { throw Error.conflict("返金済み取引に Credit は付与できません。") }
            }

            guard let credit = try await creditsRepository.get(storeId: storeId) else { throw Error.notFound("Credit 残高が見つかりません。") }
            let lastPurchasedAt = max(credit.lastPurchasedAt ?? .distantPast, verified.purchasedAt)
            let record = PurchaseRecord(
                transactionId: verified.transactionId,
                storeId: storeId,
                appAccountToken: verified.appAccountToken,
                productId: verified.productId,
                creditedAmount: amount,
                purchasedAt: verified.purchasedAt,
                environment: verified.environment,
                creditGranted: true,
                refundStatus: old?.refundStatus ?? .active,
                refundDeductedCredits: old?.refundDeductedCredits ?? 0,
                lastRefundEventSignedDate: old?.lastRefundEventSignedDate,
                refundedAt: old?.refundedAt
            )
            if try await purchases.grant(record, replacing: old, credit: credit, newBalance: credit.balance + amount, newLastPurchasedAt: lastPurchasedAt) {
                return PurchaseResult(transactionId: verified.transactionId, creditedAmount: amount, balance: credit.balance + amount)
            }
        }
        throw Error.conflict("購入処理が競合しました。時間をおいて再試行してください。")
    }

    func applyNotification(signedPayload: String) async throws {
        let notification = try await appStore.verifyNotification(signedPayload: signedPayload)
        guard notification.type != .other, let verified = notification.purchase else { return }
        let refundStatus: PurchaseRefundStatus = notification.type == .refund ? .refunded : .active
        let amount = AdvertisingEnvironment().productCredits[verified.productId] ?? 0

        for _ in 0..<5 {
            guard let old = try await purchases.get(transactionId: verified.transactionId) else {
                let marker = PurchaseRecord(
                    transactionId: verified.transactionId,
                    storeId: nil,
                    appAccountToken: verified.appAccountToken,
                    productId: verified.productId,
                    creditedAmount: amount,
                    purchasedAt: verified.purchasedAt,
                    environment: verified.environment,
                    creditGranted: false,
                    refundStatus: refundStatus,
                    refundDeductedCredits: 0,
                    lastRefundEventSignedDate: notification.signedDate,
                    refundedAt: refundStatus == .refunded ? verified.revocationDate ?? notification.signedDate : nil
                )
                if try await purchases.createRefundMarker(marker) { return }
                continue
            }

            try validate(old, matches: verified)
            if let previousEventDate = old.lastRefundEventSignedDate,
               notification.signedDate <= previousEventDate {
                return
            }

            var updated = PurchaseRecord(
                transactionId: old.transactionId,
                storeId: old.storeId,
                appAccountToken: old.appAccountToken,
                productId: old.productId,
                creditedAmount: old.creditedAmount,
                purchasedAt: old.purchasedAt,
                environment: old.environment,
                creditGranted: old.creditGranted,
                refundStatus: refundStatus,
                refundDeductedCredits: old.refundDeductedCredits,
                lastRefundEventSignedDate: notification.signedDate,
                refundedAt: refundStatus == .refunded ? verified.revocationDate ?? notification.signedDate : nil
            )

            var account: CreditAccount?
            var newBalance: Int?
            if old.creditGranted, old.refundStatus != refundStatus {
                guard let storeId = old.storeId,
                      let credit = try await creditsRepository.get(storeId: storeId) else {
                    throw Error.internalServerError("購入済み Credit の店舗残高を取得できません。")
                }
                account = credit
                if refundStatus == .refunded {
                    let deduction = min(max(0, old.creditedAmount), credit.balance)
                    updated.refundDeductedCredits = deduction
                    newBalance = credit.balance - deduction
                } else {
                    newBalance = credit.balance + max(0, old.refundDeductedCredits)
                    updated.refundDeductedCredits = 0
                }
            }

            if try await purchases.applyNotification(updated, replacing: old, credit: account, newBalance: newBalance) {
                return
            }
        }
        throw Error.conflict("返金通知の処理が競合しました。")
    }

    private func advertiserId(_ user: UserRole) throws -> String {
        switch user {
        case let .advertiser(id) where !id.isEmpty:
            return id
        case .guest:
            throw Error.unauthorized("広告主としてログインしてください。")
        default:
            throw Error.forbidden("広告主としてログインしてください。")
        }
    }

    private func validate(_ record: PurchaseRecord, matches purchase: VerifiedPurchase, store: Store) throws {
        try validate(record, matches: purchase)
        let storeMatches = record.creditGranted
            ? record.storeId == store.id
            : record.storeId == nil || record.storeId == store.id
        guard storeMatches,
              record.appAccountToken == store.purchaseAccountToken else {
            throw Error.conflict("この購入取引は別の店舗に紐付いています。")
        }
    }

    private func validate(_ record: PurchaseRecord, matches purchase: VerifiedPurchase) throws {
        guard record.transactionId == purchase.transactionId,
              record.productId == purchase.productId,
              record.appAccountToken == purchase.appAccountToken,
              record.purchasedAt == purchase.purchasedAt,
              record.environment == purchase.environment else {
            throw Error.conflict("購入台帳と Apple 取引の内容が一致しません。")
        }
    }
}
