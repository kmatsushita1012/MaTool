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
