import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct PurchaseRepositoryTest {
    @Test("購入付与は台帳・店舗履歴・Credit を一つの transaction にまとめる")
    func grantWritesAllRecordsAtomically() async throws {
        let record = makeRecord()
        let credit = CreditAccount(storeId: "store-1", balance: 100)
        let dataStore = DataStoreMock(transactWriteHandler: { _ in })
        let credits = CreditRepositorySpy(account: credit)

        let committed = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
            $0[CreditRepositoryKey.self] = credits
        } operation: {
            try await PurchaseRepository().grant(
                record,
                replacing: nil,
                credit: credit,
                newBalance: 600,
                newLastPurchasedAt: record.purchasedAt
            )
        }

        #expect(committed)
        guard let writes = dataStore.lastTransaction else {
            Issue.record("購入の transaction が記録されていません。")
            return
        }
        #expect(writes.count == 3)
        guard case let .put(_, purchaseCondition, _, _) = writes[0],
              case let .put(_, historyCondition, _, _) = writes[1],
              case .update = writes[2] else {
            Issue.record("購入・履歴・Credit の3操作が transaction に含まれていません。")
            return
        }
        #expect(purchaseCondition == "attribute_not_exists(#pk)")
        #expect(historyCondition == "attribute_not_exists(#pk)")
    }

    @Test("transaction が既存購入と Credit 競合を検出した場合は二重付与しない")
    func grantReturnsFalseWhenTransactionWasAlreadyApplied() async throws {
        let record = makeRecord()
        let credit = CreditAccount(storeId: "store-1", balance: 600, lastPurchasedAt: record.purchasedAt)
        let existingRecord = try JSONEncoder().encode(Record(
            pk: "PURCHASE#\(record.transactionId)",
            sk: "METADATA",
            content: record
        ))
        let dataStore = DataStoreMock(
            getHandler: { _, _ in existingRecord },
            transactWriteHandler: { _ in throw TestError.intentional }
        )
        let credits = CreditRepositorySpy(account: credit)

        let committed = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
            $0[CreditRepositoryKey.self] = credits
        } operation: {
            try await PurchaseRepository().grant(
                record,
                replacing: nil,
                credit: CreditAccount(storeId: "store-1", balance: 100),
                newBalance: 600,
                newLastPurchasedAt: record.purchasedAt
            )
        }

        #expect(!committed)
        #expect(dataStore.lastTransaction?.count == 3)
    }

    @Test("返金状態の更新と Credit 減算は一つの条件付き transaction で確定する")
    func refundNotificationUpdatesPurchaseAndCreditAtomically() async throws {
        var oldRecord = makeRecord()
        oldRecord.lastRefundEventSignedDate = Date(timeIntervalSince1970: 1_700_000_050)
        let refundedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let newRecord = PurchaseRecord(
            transactionId: oldRecord.transactionId,
            storeId: oldRecord.storeId,
            appAccountToken: oldRecord.appAccountToken,
            productId: oldRecord.productId,
            creditedAmount: oldRecord.creditedAmount,
            purchasedAt: oldRecord.purchasedAt,
            environment: oldRecord.environment,
            creditGranted: true,
            refundStatus: .refunded,
            refundDeductedCredits: 100,
            lastRefundEventSignedDate: refundedAt,
            refundedAt: refundedAt
        )
        let credit = CreditAccount(storeId: "store-1", balance: 100)
        let dataStore = DataStoreMock(transactWriteHandler: { _ in })
        let credits = CreditRepositorySpy(account: credit)

        let committed = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
            $0[CreditRepositoryKey.self] = credits
        } operation: {
            try await PurchaseRepository().applyNotification(
                newRecord,
                replacing: oldRecord,
                credit: credit,
                newBalance: 0
            )
        }

        #expect(committed)
        guard let writes = dataStore.lastTransaction,
              writes.count == 2,
              case let .put(_, purchaseCondition, _, _) = writes[0],
              case let .update(_, _, balanceCondition, _, _) = writes[1] else {
            Issue.record("返金状態と Credit 更新が同一 transaction にありません。")
            return
        }
        #expect(purchaseCondition?.contains("#content.#lastRefundDate = :lastRefundDate") == true)
        #expect(balanceCondition?.contains("#content.#balance = :oldBalance") == true)
    }
    @Test("transactionIdから購入台帳を強整合読み取りする")
    func getFetchesPurchaseByExactKey() async throws {
        let record = makeRecord()
        var readKeys: [String: Codable] = [:]
        let dataStore = DataStoreMock(getHandler: { keys, _ in
            readKeys = keys
            return try encodeForDataStore(Record(
                pk: "PURCHASE#transaction-1", sk: "METADATA", content: record
            ))
        })

        let fetched = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            try await PurchaseRepository().get(transactionId: record.transactionId)
        }

        #expect(fetched == record)
        #expect(readKeys["pk"] as? String == "PURCHASE#transaction-1")
        #expect(readKeys["sk"] as? String == "METADATA")
    }

    @Test("購入履歴は店舗PKに限定し新しい順へ並ぶqueryを指定する")
    func historyUsesStorePartitionAndDescendingQuery() async throws {
        let record = makeRecord()
        let history = PurchaseHistoryItem(
            transactionId: record.transactionId,
            productId: record.productId,
            creditedAmount: record.creditedAmount,
            purchasedAt: record.purchasedAt
        )
        var wasDescending = false
        let dataStore = DataStoreMock(queryHandler: { index, conditions, filters, limit, ascending, _ in
            #expect(index == nil)
            #expect(conditions.count == 2)
            #expect(filters.isEmpty)
            #expect(limit == nil)
            wasDescending = !ascending
            return try encodeForDataStore([
                Record(pk: "STORE#store-1", sk: "PURCHASE#2026#transaction-1", content: history)
            ])
        })

        let entries = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            try await PurchaseRepository().history(storeId: "store-1")
        }

        #expect(wasDescending)
        #expect(entries.count == 1)
        #expect(entries.first?.transactionId == record.transactionId)
    }

    @Test("返金マーカーの新規登録は購入台帳に条件付き一件Putする")
    func refundMarkerCreateUsesConditionalPut() async throws {
        let marker = makeRecord()
        let dataStore = DataStoreMock(transactWriteHandler: { _ in })

        let inserted = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            try await PurchaseRepository().createRefundMarker(marker)
        }

        #expect(inserted)
        let writes = try #require(dataStore.lastTransaction)
        #expect(writes.count == 1)
        guard case let .put(_, condition, _, _) = writes[0] else {
            Issue.record("返金マーカーがPutではない")
            return
        }
        #expect(condition == "attribute_not_exists(#pk)")
    }

    @Test("既存マーカーが競合した場合は再作成せずfalseを返す")
    func existingRefundMarkerIsIdempotent() async throws {
        let marker = makeRecord()
        let dataStore = DataStoreMock(
            getHandler: { _, _ in
                try encodeForDataStore(Record(
                    pk: "PURCHASE#transaction-1", sk: "METADATA", content: marker
                ))
            },
            transactWriteHandler: { _ in throw TestError.intentional }
        )

        let inserted = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            try await PurchaseRepository().createRefundMarker(marker)
        }

        #expect(!inserted)
    }

    @Test("既存の未付与レコードを付与する際は返金日時も楽観ロック条件へ入れる")
    func grantWithPriorRefundDateChecksPriorVersion() async throws {
        var prior = makeRecord()
        prior.creditGranted = false
        prior.lastRefundEventSignedDate = Date(timeIntervalSince1970: 1_700_000_100)
        let credit = CreditAccount(storeId: "store-1", balance: 0)
        let dataStore = DataStoreMock(transactWriteHandler: { _ in })

        let updated = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            try await PurchaseRepository().grant(
                makeRecord(), replacing: prior, credit: credit,
                newBalance: 500, newLastPurchasedAt: prior.purchasedAt
            )
        }

        #expect(updated)
        let writes = try #require(dataStore.lastTransaction)
        guard case let .put(_, condition, _, values) = writes[0] else {
            Issue.record("購入台帳の更新がPutではない")
            return
        }
        #expect(condition?.contains("#content.#lastRefundDate = :lastRefundDate") == true)
        #expect(values[":lastRefundDate"] != nil)
    }


    @Test("店舗IDのない購入台帳をCreditへ付与することを拒否する")
    func grantRequiresStoreID() async {
        let old = makeRecord()
        let record = PurchaseRecord(
            transactionId: old.transactionId,
            storeId: nil,
            appAccountToken: old.appAccountToken,
            productId: old.productId,
            creditedAmount: old.creditedAmount,
            purchasedAt: old.purchasedAt,
            environment: old.environment
        )
        let dataStore = DataStoreMock()
        await #expect(throws: Error.internalServerError("購入記録に店舗IDがありません。")) {
            try await withDependencies {
                $0.dataStoreFactory = { _ in dataStore }
            } operation: {
                try await PurchaseRepository().grant(
                    record, replacing: nil,
                    credit: CreditAccount(storeId: "store-1", balance: 0),
                    newBalance: 500, newLastPurchasedAt: record.purchasedAt
                )
            }
        }
        #expect(dataStore.lastTransaction == nil)
    }

    @Test("通知処理の競合でより新しい台帳が存在すれば古い更新を諦める")
    func outdatedNotificationCannotOverwriteNewerPurchase() async throws {
        let old = makeRecord()
        var latest = old
        latest.refundStatus = .refunded
        let dataStore = DataStoreMock(
            getHandler: { _, _ in
                try encodeForDataStore(Record(
                    pk: "PURCHASE#transaction-1", sk: "METADATA", content: latest
                ))
            },
            transactWriteHandler: { _ in throw TestError.intentional }
        )

        let applied = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            try await PurchaseRepository().applyNotification(
                old, replacing: old, credit: nil, newBalance: nil
            )
        }
        #expect(!applied)
        #expect(dataStore.lastTransaction?.count == 1)
    }

    @Test("既存台帳の存在しないマーカー作成失敗は元のDB障害を伝播する")
    func refundMarkerPersistsDatabaseErrors() async {
        let dataStore = DataStoreMock(
            getHandler: { _, _ in nil },
            transactWriteHandler: { _ in throw TestError.intentional }
        )
        await #expect(throws: TestError.intentional) {
            try await withDependencies {
                $0.dataStoreFactory = { _ in dataStore }
            } operation: {
                try await PurchaseRepository().createRefundMarker(makeRecord())
            }
        }
    }

    @Test("Credit変動なしの返金通知は台帳だけを書き換える")
    func notificationWithoutBalanceChangeWritesSingleRecord() async throws {
        let prior = makeRecord()
        var updated = prior
        updated.refundStatus = .refunded
        let dataStore = DataStoreMock(transactWriteHandler: { _ in })

        let applied = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            try await PurchaseRepository().applyNotification(
                updated, replacing: prior,
                credit: CreditAccount(storeId: "store-1", balance: 10),
                newBalance: 10
            )
        }

        #expect(applied)
        let writes = try #require(dataStore.lastTransaction)
        #expect(writes.count == 1)
        guard case let .put(_, condition, _, _) = writes[0] else {
            Issue.record("返金通知の更新がPutではない")
            return
        }
        #expect(condition?.contains("attribute_type(#content.#lastRefundDate") == true)
    }


}

private func makeRecord() -> PurchaseRecord {
    PurchaseRecord(
        transactionId: "transaction-1",
        storeId: "store-1",
        appAccountToken: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        productId: "credit-500",
        creditedAmount: 500,
        purchasedAt: Date(timeIntervalSince1970: 1_700_000_000),
        environment: "Sandbox",
        creditGranted: true
    )
}
