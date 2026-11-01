import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct AppStoreNotificationHistoryRecoveryTest {
    @Test("指定期間の失敗通知を取得し、署名検証を経て既存処理へ再投入する")
    func recoversFailedNotificationsIdempotently() async throws {
        let start = "2026-10-30T00:00:00Z"
        let end = "2026-10-31T00:00:00Z"
        let history = AppStoreNotificationHistoryClientSpy(payloads: ["failed-1", "failed-2"])
        let appStore = AppStoreClientSpy(purchase: makePurchase(), notification: .init(
            notificationUUID: nil,
            type: .other,
            signedDate: Date(timeIntervalSince1970: 2_000),
            purchase: nil
        ))

        let count = try await withDependencies {
            $0[AdvertisingEnvironmentKey.self] = AdvertisingEnvironment(environment: ["APP_STORE_ENVIRONMENT": "sandbox"])
            $0[AppStoreNotificationHistoryClientKey.self] = history
            $0[AppStoreClientKey.self] = appStore
        } operation: {
            try await AppStoreNotificationHistoryRecovery().run(startDate: start, endDate: end)
        }

        #expect(count == 2)
        #expect(await appStore.notificationVerificationCallCount == 2)
        #expect(await history.requestedRange?.0 == ISO8601DateFormatter().date(from: start))
        #expect(await history.requestedRange?.1 == ISO8601DateFormatter().date(from: end))
    }

    @Test("180日より古い範囲は Apple API 呼び出し前に拒否する")
    func rejectsExpiredHistoryRange() async {
        let history = AppStoreNotificationHistoryClientSpy(payloads: [])
        let start = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1))
        let end = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 2))

        await #expect(throws: Error.badRequest("開始・終了日時はUTC ISO 8601形式で指定し、過去180日以内の期間にしてください。")) {
            try await withDependencies {
                $0[AdvertisingEnvironmentKey.self] = AdvertisingEnvironment(environment: ["APP_STORE_ENVIRONMENT": "sandbox"])
                $0[AppStoreNotificationHistoryClientKey.self] = history
            } operation: {
                try await AppStoreNotificationHistoryRecovery().run(startDate: start, endDate: end)
            }
        }

        #expect(await history.requestedRange == nil)
    }
}

private func makePurchase() -> VerifiedPurchase {
    VerifiedPurchase(
        transactionId: "transaction-1",
        appAccountToken: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        productId: "credit-500",
        purchasedAt: Date(timeIntervalSince1970: 500),
        environment: "Sandbox",
        revocationDate: nil,
        isConsumable: true
    )
}
