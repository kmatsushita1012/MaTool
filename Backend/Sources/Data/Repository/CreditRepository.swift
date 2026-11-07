import Dependencies
import Foundation
import Shared

enum CreditRepositoryKey: DependencyKey {
    static let liveValue: any CreditRepositoryProtocol = CreditRepository()
}

extension DependencyValues {
    var creditRepository: any CreditRepositoryProtocol {
        get { self[CreditRepositoryKey.self] }
        set { self[CreditRepositoryKey.self] = newValue }
    }
}

protocol CreditRepositoryProtocol: Sendable {
    func get(storeId: Store.ID) async throws -> CreditAccount?
}

struct CreditRepository: CreditRepositoryProtocol {
    private let store: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        store = storeFactory("matool")
    }

    func get(storeId: Store.ID) async throws -> CreditAccount? {
        try await store.get(pk: "STORE#\(storeId)", sk: "CREDIT", consistentRead: true, as: CreditRecord.self)?.content
    }

    static func balanceUpdate(storeId: Store.ID, expected: CreditAccount, newBalance: Int, newLastPurchasedAt: Date? = nil) throws -> DynamoDBTransactionOperation {
        let encoder = DynamoDBEncoder()
        let key = ["pk": try encoder.encodeKey("STORE#\(storeId)"), "sk": try encoder.encodeKey("CREDIT")]
        let names = ["#pk": "pk", "#sk": "sk", "#content": "content", "#balance": "balance", "#lastPurchasedAt": "last_purchased_at"]
        var values: [String: DynamoDBAttribute] = [
            ":oldBalance": try encoder.encodeValue(expected.balance),
            ":newBalance": try encoder.encodeValue(newBalance),
            ":nullType": try encoder.encodeValue("NULL")
        ]
        var condition = "attribute_exists(#pk) AND attribute_exists(#sk) AND #content.#balance = :oldBalance"
        if let oldDate = expected.lastPurchasedAt {
            values[":oldLastPurchasedAt"] = try encoder.encodeValue(oldDate)
            condition += " AND #content.#lastPurchasedAt = :oldLastPurchasedAt"
        } else {
            condition += " AND attribute_type(#content.#lastPurchasedAt, :nullType)"
        }
        var updateExpression = "SET #content.#balance = :newBalance"
        if let newLastPurchasedAt {
            values[":newLastPurchasedAt"] = try encoder.encodeValue(newLastPurchasedAt)
            updateExpression += ", #content.#lastPurchasedAt = :newLastPurchasedAt"
        }
        return .update(
            keys: key,
            updateExpression: updateExpression,
            conditionExpression: condition,
            expressionAttributeNames: names,
            expressionAttributeValues: values
        )
    }
}

private typealias CreditRecord = Record<CreditAccount>
