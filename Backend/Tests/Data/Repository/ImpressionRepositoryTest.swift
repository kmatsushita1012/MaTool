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
}
