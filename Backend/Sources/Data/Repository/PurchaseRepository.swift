import Dependencies
import Foundation
import Shared

enum PurchaseRepositoryKey: DependencyKey {
    static let liveValue: any PurchaseRepositoryProtocol = PurchaseRepository()
}

extension DependencyValues {
    var purchaseRepository: any PurchaseRepositoryProtocol {
        get { self[PurchaseRepositoryKey.self] }
        set { self[PurchaseRepositoryKey.self] = newValue }
    }
}

protocol PurchaseRepositoryProtocol: Sendable {
    func get(transactionId: String) async throws -> PurchaseRecord?
    func history(storeId: Store.ID) async throws -> [PurchaseHistoryItem]
    func grant(_ record: PurchaseRecord, replacing oldRecord: PurchaseRecord?, credit: CreditAccount, newBalance: Int, newLastPurchasedAt: Date) async throws -> Bool
    func createRefundMarker(_ record: PurchaseRecord) async throws -> Bool
    func applyNotification(_ record: PurchaseRecord, replacing oldRecord: PurchaseRecord, credit: CreditAccount?, newBalance: Int?) async throws -> Bool
}

struct PurchaseRepository: PurchaseRepositoryProtocol {
    private let store: any DynamoDBTransactionalDataStore
    private let encoder = DynamoDBEncoder()
    @Dependency(CreditRepositoryKey.self) private var credits

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        store = storeFactory("matool")
    }

    func get(transactionId: String) async throws -> PurchaseRecord? {
        try await store.get(pk: "PURCHASE#\(transactionId)", sk: "METADATA", consistentRead: true, as: PurchaseRecordRecord.self)?.content
    }

    func history(storeId: Store.ID) async throws -> [PurchaseHistoryItem] {
        try await store.query(
            indexName: nil,
            keyConditions: [.equals("pk", "STORE#\(storeId)"), .beginsWith("sk", "PURCHASE#")],
            filterConditions: [],
            limit: nil,
            ascending: false,
            as: PurchaseHistoryRecord.self
        ).map(\.content)
    }

    func grant(
        _ record: PurchaseRecord,
        replacing oldRecord: PurchaseRecord?,
        credit: CreditAccount,
        newBalance: Int,
        newLastPurchasedAt: Date
    ) async throws -> Bool {
        guard let storeId = record.storeId else { throw Error.internalServerError("購入記録に店舗IDがありません。") }
        let condition = try purchaseCondition(replacing: oldRecord)
        let purchaseWrite = try putOperation(PurchaseRecordRecord(record), condition: condition.expression, names: condition.names, values: condition.values)
        let history = PurchaseHistoryItem(
            transactionId: record.transactionId,
            productId: record.productId,
            creditedAmount: record.creditedAmount,
            purchasedAt: record.purchasedAt
        )
        let historyKey = PurchaseHistoryRecord.keys(storeId: storeId, purchasedAt: record.purchasedAt, transactionId: record.transactionId)
        let historyRecord = PurchaseHistoryRecord(pk: historyKey.pk, sk: historyKey.sk, content: history)
        let historyWrite = try putOperation(historyRecord, condition: "attribute_not_exists(#pk)", names: ["#pk": "pk"], values: [:])
        let balanceWrite = try CreditRepository.balanceUpdate(storeId: storeId, expected: credit, newBalance: newBalance, newLastPurchasedAt: newLastPurchasedAt)

        do {
            try await store.transactWrite([purchaseWrite, historyWrite, balanceWrite])
            return true
        } catch {
            let latestPurchase = try await get(transactionId: record.transactionId)
            let latestCredit = try await credits.get(storeId: storeId)
            if latestPurchase != oldRecord || latestCredit != credit { return false }
            throw error
        }
    }

    func createRefundMarker(_ record: PurchaseRecord) async throws -> Bool {
        let write = try putOperation(PurchaseRecordRecord(record), condition: "attribute_not_exists(#pk)", names: ["#pk": "pk"], values: [:])
        do {
            try await store.transactWrite([write])
            return true
        } catch {
            if try await get(transactionId: record.transactionId) != nil { return false }
            throw error
        }
    }

    func applyNotification(
        _ record: PurchaseRecord,
        replacing oldRecord: PurchaseRecord,
        credit: CreditAccount?,
        newBalance: Int?
    ) async throws -> Bool {
        let condition = try latestRefundEventCondition(oldRecord)
        let purchaseWrite = try putOperation(PurchaseRecordRecord(record), condition: condition.expression, names: condition.names, values: condition.values)
        var writes = [purchaseWrite]
        if let credit, let newBalance, credit.balance != newBalance {
            writes.append(try CreditRepository.balanceUpdate(storeId: credit.storeId, expected: credit, newBalance: newBalance, newLastPurchasedAt: nil))
        }

        do {
            try await store.transactWrite(writes)
            return true
        } catch {
            let latestPurchase = try await get(transactionId: record.transactionId)
            if latestPurchase != oldRecord { return false }
            if let credit, let latestCredit = try await credits.get(storeId: credit.storeId), latestCredit != credit { return false }
            throw error
        }
    }

    private func purchaseCondition(replacing oldRecord: PurchaseRecord?) throws -> (expression: String, names: [String: String], values: [String: DynamoDBAttribute]) {
        guard let oldRecord else {
            return ("attribute_not_exists(#pk)", ["#pk": "pk"], [:])
        }
        let names = ["#pk": "pk", "#content": "content", "#creditGranted": "credit_granted", "#refundStatus": "refund_status", "#refundDeducted": "refund_deducted_credits", "#lastRefundDate": "last_refund_event_signed_date"]
        var values: [String: DynamoDBAttribute] = [
            ":creditGranted": try encoder.encodeValue(false),
            ":refundStatus": try encoder.encodeValue(oldRecord.refundStatus),
            ":refundDeducted": try encoder.encodeValue(oldRecord.refundDeductedCredits),
            ":nullType": try encoder.encodeValue("NULL")
        ]
        var condition = "attribute_exists(#pk) AND #content.#creditGranted = :creditGranted AND #content.#refundStatus = :refundStatus AND #content.#refundDeducted = :refundDeducted"
        if let lastDate = oldRecord.lastRefundEventSignedDate {
            values[":lastRefundDate"] = try encoder.encodeValue(lastDate)
            condition += " AND #content.#lastRefundDate = :lastRefundDate"
        } else {
            condition += " AND attribute_type(#content.#lastRefundDate, :nullType)"
        }
        return (condition, names, values)
    }

    private func latestRefundEventCondition(_ oldRecord: PurchaseRecord) throws -> (expression: String, names: [String: String], values: [String: DynamoDBAttribute]) {
        let names = [
            "#pk": "pk", "#content": "content", "#lastRefundDate": "last_refund_event_signed_date",
            "#creditGranted": "credit_granted", "#refundStatus": "refund_status", "#refundDeducted": "refund_deducted_credits"
        ]
        var values: [String: DynamoDBAttribute] = [":nullType": try encoder.encodeValue("NULL")]
        values[":creditGranted"] = try encoder.encodeValue(oldRecord.creditGranted)
        values[":refundStatus"] = try encoder.encodeValue(oldRecord.refundStatus)
        values[":refundDeducted"] = try encoder.encodeValue(oldRecord.refundDeductedCredits)
        var condition = "attribute_exists(#pk) AND #content.#creditGranted = :creditGranted AND #content.#refundStatus = :refundStatus AND #content.#refundDeducted = :refundDeducted"
        if let lastDate = oldRecord.lastRefundEventSignedDate {
            values[":lastRefundDate"] = try encoder.encodeValue(lastDate)
            condition += " AND #content.#lastRefundDate = :lastRefundDate"
        } else {
            condition += " AND attribute_type(#content.#lastRefundDate, :nullType)"
        }
        return (condition, names, values)
    }

    private func putOperation<R: RecordProtocol>(
        _ record: R,
        condition: String,
        names: [String: String],
        values: [String: DynamoDBAttribute]
    ) throws -> DynamoDBTransactionOperation {
        .put(
            item: try encoder.encode(record),
            conditionExpression: condition,
            expressionAttributeNames: names,
            expressionAttributeValues: values
        )
    }
}

private typealias PurchaseRecordRecord = Record<PurchaseRecord>
private typealias PurchaseHistoryRecord = Record<PurchaseHistoryItem>

private extension Record where Content == PurchaseRecord {
    init(_ content: PurchaseRecord) {
        self.init(pk: "PURCHASE#\(content.transactionId)", sk: "METADATA", content: content)
    }
}

private extension Record where Content == PurchaseHistoryItem {
    static func keys(storeId: Store.ID, purchasedAt: Date, transactionId: String) -> (pk: String, sk: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return ("STORE#\(storeId)", "PURCHASE#\(formatter.string(from: purchasedAt))#\(transactionId)")
    }
}
