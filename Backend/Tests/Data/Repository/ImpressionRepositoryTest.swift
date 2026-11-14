import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct ImpressionRepositoryTest {
    @Test("重複防止レコードは token 期限より長い TTL を持つ")
    func chargeWritesThirtyDayExpirationAtTopLevel() async throws {
        let chargedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let dataStore = DataStoreMock(
            getHandler: { _, _ in nil },
            transactWriteHandler: { _ in }
        )
        let credits = CreditRepositorySpy(account: CreditAccount(storeId: "store-1", balance: 10))

        let result = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
            $0[CreditRepositoryKey.self] = credits
        } operation: {
            try await ImpressionRepository().charge(
                impressionId: "impression-1",
                storeId: "store-1",
                placement: .banner,
                chargedAt: chargedAt
            )
        }

        #expect(result == .charged)
        guard let transaction = dataStore.lastTransaction,
              case let .put(item, _, _, _) = transaction.first else {
            Issue.record("Impression の条件付き作成が transaction にありません。")
            return
        }
        guard case let .n(expirationText)? = item["expires_at"], let expiration = Int64(expirationText) else {
            Issue.record("expires_at がトップレベルの Unix epoch 秒として保存されていません。")
            return
        }
        #expect(expiration == Int64(chargedAt.timeIntervalSince1970) + 30 * 24 * 60 * 60)
    }

    @Test("Impression 作成と Credit 減算は条件付き transaction に含まれる")
    func chargeAtomicallyCreatesImpressionAndDecreasesCredit() async throws {
        let dataStore = DataStoreMock(
            getHandler: { _, _ in nil },
            transactWriteHandler: { _ in }
        )
        let credits = CreditRepositorySpy(account: CreditAccount(storeId: "store-1", balance: 10))

        let result = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
            $0[CreditRepositoryKey.self] = credits
        } operation: {
            try await ImpressionRepository().charge(
                impressionId: "impression-2",
                storeId: "store-1",
                placement: .banner,
                chargedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        }

        #expect(result == .charged)
        guard let transaction = dataStore.lastTransaction,
              transaction.count == 2,
              case let .put(_, impressionCondition, _, _) = transaction[0],
              case let .update(_, _, balanceCondition, _, _) = transaction[1] else {
            Issue.record("Impression 作成と Credit 更新が同一 transaction にありません。")
            return
        }
        #expect(impressionCondition == "attribute_not_exists(#pk)")
        #expect(balanceCondition?.contains("#content.#balance = :oldBalance") == true)
    }
    @Test("残高不足の表示ではDynamoDBの課金トランザクションを作成しない")
    func insufficientCreditDoesNotWriteTransaction() async throws {
        let dataStore = DataStoreMock(getHandler: { _, _ in nil })
        let credits = CreditRepositorySpy(account: CreditAccount(storeId: "store-1", balance: 1))
        let result = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
            $0[CreditRepositoryKey.self] = credits
        } operation: {
            try await ImpressionRepository().charge(
                impressionId: "impression-10",
                storeId: "store-1",
                placement: .interstitial,
                chargedAt: Date()
            )
        }

        #expect(result == .insufficientBalance)
        #expect(dataStore.lastTransaction == nil)
    }

    @Test("Credit残高のない店舗は課金せずnotFoundを返す")
    func missingCreditAccountFailsBeforeCharging() async {
        let dataStore = DataStoreMock(getHandler: { _, _ in nil })
        await #expect(throws: Error.notFound("Credit 残高が見つかりません。")) {
            try await withDependencies {
                $0.dataStoreFactory = { _ in dataStore }
                $0[CreditRepositoryKey.self] = CreditRepositorySpy()
            } operation: {
                try await ImpressionRepository().charge(
                    impressionId: "impression-11",
                    storeId: "store-1",
                    placement: .banner,
                    chargedAt: Date()
                )
            }
        }
        #expect(dataStore.lastTransaction == nil)
    }

    @Test("トランザクションが失敗し残高が不変ならDB障害を握りつぶさずに伝播する")
    func unchangedCreditAfterWriteFailurePropagatesError() async {
        let dataStore = DataStoreMock(
            getHandler: { _, _ in nil },
            transactWriteHandler: { _ in throw TestError.intentional }
        )
        let credits = CreditRepositorySpy(account: CreditAccount(storeId: "store-1", balance: 10))

        await #expect(throws: TestError.intentional) {
            try await withDependencies {
                $0.dataStoreFactory = { _ in dataStore }
                $0[CreditRepositoryKey.self] = credits
            } operation: {
                try await ImpressionRepository().charge(
                    impressionId: "impression-conflict",
                    storeId: "store-1",
                    placement: .banner,
                    chargedAt: Date()
                )
            }
        }
        #expect(dataStore.lastTransaction?.count == 2)
    }

    @Test("残高競合が発生した場合は最新残高を読み直して条件付き書き込みを再試行する")
    func changedCreditAfterWriteFailureIsRetried() async throws {
        let credits = CreditRepositorySpy(account: CreditAccount(storeId: "store-1", balance: 10))
        var attempts = 0
        let dataStore = DataStoreMock(
            getHandler: { _, _ in nil },
            transactWriteHandler: { _ in
                attempts += 1
                if attempts == 1 {
                    await credits.set(CreditAccount(storeId: "store-1", balance: 9))
                    throw TestError.intentional
                }
            }
        )

        let result = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
            $0[CreditRepositoryKey.self] = credits
        } operation: {
            try await ImpressionRepository().charge(
                impressionId: "impression-retry",
                storeId: "store-1",
                placement: .banner,
                chargedAt: Date()
            )
        }

        #expect(result == .charged)
        #expect(attempts == 2)
        #expect(dataStore.lastTransaction?.count == 2)
    }


}
