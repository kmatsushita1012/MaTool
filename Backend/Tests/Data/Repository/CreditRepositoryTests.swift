import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct CreditRepositoryTests {
    @Test("店舗残高はSTOREキーの強整合読み取りで取得する")
    func getCreditAccountByStoreKey() async throws {
        let account = CreditAccount(storeId: "store-1", balance: 27)
        var observed: [String: Codable] = [:]
        let dataStore = DataStoreMock(getHandler: { keys, _ in
            observed = keys
            return try encodeForDataStore(Record(pk: "STORE#store-1", sk: "CREDIT", content: account))
        })

        let loaded = try await withDependencies {
            $0.dataStoreFactory = { name in
                #expect(name == "matool")
                return dataStore
            }
        } operation: {
            try await CreditRepository().get(storeId: "store-1")
        }

        #expect(loaded?.balance == 27)
        #expect(loaded?.storeId == "store-1")
        #expect(observed["pk"] as? String == "STORE#store-1")
        #expect(observed["sk"] as? String == "CREDIT")
        #expect(dataStore.getCallCount == 1)
    }

    @Test("残高レコードが存在しない場合はnilを返す")
    func missingCreditAccountReturnsNil() async throws {
        let store = DataStoreMock(getHandler: { _, _ in nil })
        let loaded = try await withDependencies {
            $0.dataStoreFactory = { _ in store }
        } operation: {
            try await CreditRepository().get(storeId: "unknown")
        }
        #expect(loaded == nil)
    }

    @Test("最終購入日時の更新は楽観ロック条件と更新式の両方に日付を設定する")
    func balanceUpdateConditionsOnPriorPurchaseDate() throws {
        let old = Date(timeIntervalSince1970: 1_700_000_000)
        let newer = Date(timeIntervalSince1970: 1_700_010_000)
        let expected = CreditAccount(storeId: "store-1", balance: 10, lastPurchasedAt: old)
        let action = try CreditRepository.balanceUpdate(
            storeId: "store-1", expected: expected, newBalance: 8, newLastPurchasedAt: newer
        )
        guard case let .update(_, expression, condition, _, values) = action else {
            Issue.record("残高更新が条件付きDynamoDB Updateではない")
            return
        }

        #expect(expression.contains("#content.#balance = :newBalance"))
        #expect(expression.contains("#content.#lastPurchasedAt = :newLastPurchasedAt"))
        #expect(condition?.contains("#content.#lastPurchasedAt = :oldLastPurchasedAt") == true)
        #expect(values[":oldLastPurchasedAt"] != nil)
        #expect(values[":newLastPurchasedAt"] != nil)
    }
}
