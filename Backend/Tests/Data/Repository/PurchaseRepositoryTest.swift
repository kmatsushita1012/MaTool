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
