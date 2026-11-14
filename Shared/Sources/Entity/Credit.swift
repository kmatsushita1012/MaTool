import Foundation

public struct CreditAccount: Entity, Identifiable {
    public let storeId: Store.ID
    public var balance: Int
    @NullEncodable public var lastPurchasedAt: Date?
    public var id: String { storeId }

    public init(storeId: Store.ID, balance: Int, lastPurchasedAt: Date? = nil) {
        self.storeId = storeId
        self.balance = balance
        self.lastPurchasedAt = lastPurchasedAt
    }
}

public enum PurchaseRefundStatus: String, Entity {
    case active
    case refunded
}

public struct PurchaseRecord: Entity, Identifiable {
    public let transactionId: String
    @NullEncodable public var storeId: Store.ID?
    @NullEncodable public var appAccountToken: UUID?
    public let productId: String
    public let creditedAmount: Int
    public let purchasedAt: Date
    public let environment: String
    public var creditGranted: Bool
    public var refundStatus: PurchaseRefundStatus
    public var refundDeductedCredits: Int
    @NullEncodable public var lastRefundEventSignedDate: Date?
    @NullEncodable public var refundedAt: Date?
    public var id: String { transactionId }

    public init(
        transactionId: String,
        storeId: Store.ID?,
        appAccountToken: UUID?,
        productId: String,
        creditedAmount: Int,
        purchasedAt: Date,
        environment: String,
        creditGranted: Bool = false,
        refundStatus: PurchaseRefundStatus = .active,
        refundDeductedCredits: Int = 0,
        lastRefundEventSignedDate: Date? = nil,
        refundedAt: Date? = nil
    ) {
        self.transactionId = transactionId
        self.storeId = storeId
        self.appAccountToken = appAccountToken
        self.productId = productId
        self.creditedAmount = creditedAmount
        self.purchasedAt = purchasedAt
        self.environment = environment
        self.creditGranted = creditGranted
        self.refundStatus = refundStatus
        self.refundDeductedCredits = refundDeductedCredits
        self.lastRefundEventSignedDate = lastRefundEventSignedDate
        self.refundedAt = refundedAt
    }
}

public struct PurchaseHistoryItem: DTO, Identifiable {
    public let transactionId: String
    public let productId: String
    public let creditedAmount: Int
    public let purchasedAt: Date
    public var id: String { transactionId }

    public init(transactionId: String, productId: String, creditedAmount: Int, purchasedAt: Date) {
        self.transactionId = transactionId
        self.productId = productId
        self.creditedAmount = creditedAmount
        self.purchasedAt = purchasedAt
    }
}

public struct PurchaseClaimRequest: DTO {
    public let signedTransactionInfo: String
    public init(signedTransactionInfo: String) { self.signedTransactionInfo = signedTransactionInfo }
}

public struct PurchaseResult: DTO {
    public let transactionId: String
    public let creditedAmount: Int
    public let balance: Int

    public init(transactionId: String, creditedAmount: Int, balance: Int) {
        self.transactionId = transactionId
        self.creditedAmount = creditedAmount
        self.balance = balance
    }
}

public struct AppStoreNotificationRequest: DTO {
    public let signedPayload: String
    public init(signedPayload: String) { self.signedPayload = signedPayload }
}
