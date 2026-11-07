import Foundation
import Shared
@testable import Backend

actor StoreRepositorySpy: StoreRepositoryProtocol {
    var storedStore: Store?

    init(store: Store? = nil) {
        self.storedStore = store
    }

    func get(id: Store.ID, festivalId: Festival.ID, consistentRead: Bool) async throws -> Store? {
        guard let storedStore, storedStore.id == id, storedStore.festivalId == festivalId else { return nil }
        return storedStore
    }

    func find(id: Store.ID) async throws -> Store? {
        storedStore?.id == id ? storedStore : nil
    }

    func getOwned(id: Store.ID, ownerId: String) async throws -> Store? {
        guard let storedStore, storedStore.id == id, storedStore.ownerId == ownerId else { return nil }
        return storedStore
    }

    func storesOwned(by ownerId: String) async throws -> [Store] {
        storedStore?.ownerId == ownerId ? [storedStore!] : []
    }

    func stores(in festivalId: Festival.ID) async throws -> [Store] {
        storedStore?.festivalId == festivalId ? [storedStore!] : []
    }

    func create(_ store: Store) async throws {
        storedStore = store
    }

    func updateEditableFields(_ store: Store, requireApproved: Bool) async throws -> Store {
        storedStore = store
        return store
    }
}

actor CreditRepositorySpy: CreditRepositoryProtocol {
    private var account: CreditAccount?

    init(account: CreditAccount? = nil) {
        self.account = account
    }

    func get(storeId: Store.ID) async throws -> CreditAccount? {
        account?.storeId == storeId ? account : nil
    }

    func set(_ account: CreditAccount) {
        self.account = account
    }
}

actor PurchaseRepositorySpy: PurchaseRepositoryProtocol {
    private var records: [String: PurchaseRecord] = [:]
    private(set) var grantCalls: [PurchaseRecord] = []
    private(set) var refundMarkerCalls: [PurchaseRecord] = []
    private(set) var notificationCalls: [PurchaseRecord] = []
    private var grantResult = true

    init(records: [PurchaseRecord] = [], grantResult: Bool = true) {
        self.records = Dictionary(uniqueKeysWithValues: records.map { ($0.transactionId, $0) })
        self.grantResult = grantResult
    }

    func get(transactionId: String) async throws -> PurchaseRecord? {
        records[transactionId]
    }

    func history(storeId: Store.ID) async throws -> [PurchaseHistoryItem] { [] }

    func grant(_ record: PurchaseRecord, replacing oldRecord: PurchaseRecord?, credit: CreditAccount, newBalance: Int, newLastPurchasedAt: Date) async throws -> Bool {
        grantCalls.append(record)
        if grantResult { records[record.transactionId] = record }
        return grantResult
    }

    func createRefundMarker(_ record: PurchaseRecord) async throws -> Bool {
        refundMarkerCalls.append(record)
        records[record.transactionId] = record
        return true
    }

    func applyNotification(_ record: PurchaseRecord, replacing oldRecord: PurchaseRecord, credit: CreditAccount?, newBalance: Int?) async throws -> Bool {
        notificationCalls.append(record)
        records[record.transactionId] = record
        return true
    }

    func set(_ record: PurchaseRecord) {
        records[record.transactionId] = record
    }
}

actor AppStoreClientSpy: AppStoreClientProtocol {
    private let purchase: VerifiedPurchase
    private var current: VerifiedPurchase
    private var notification: VerifiedPurchaseNotification
    private(set) var currentPurchaseCallCount = 0
    private(set) var notificationVerificationCallCount = 0

    init(purchase: VerifiedPurchase, current: VerifiedPurchase? = nil, notification: VerifiedPurchaseNotification) {
        self.purchase = purchase
        self.current = current ?? purchase
        self.notification = notification
    }

    func verifyPurchase(signedTransactionInfo: String) async throws -> VerifiedPurchase { purchase }

    func currentPurchase(transactionId: String, environment: String) async throws -> VerifiedPurchase {
        currentPurchaseCallCount += 1
        return current
    }

    func verifyNotification(signedPayload: String) async throws -> VerifiedPurchaseNotification {
        notificationVerificationCallCount += 1
        return notification
    }

    func setNotification(_ notification: VerifiedPurchaseNotification) {
        self.notification = notification
    }
}

actor AppStoreNotificationHistoryClientSpy: AppStoreNotificationHistoryClientProtocol {
    private let payloads: [String]
    private(set) var requestedRange: (Date, Date)?

    init(payloads: [String]) {
        self.payloads = payloads
    }

    func failedNotifications(startDate: Date, endDate: Date) async throws -> [String] {
        requestedRange = (startDate, endDate)
        return payloads
    }
}
