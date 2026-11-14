import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct ImpressionUsecaseTests {
    private let secret = String(repeating: "s", count: 32)

    @Test("有効な表示tokenは該当店舗に対し課金を一度だけ依頼する")
    func validReportChargesExpectedStore() async throws {
        let store = makeStore()
        let charging = RecordingImpressionRepositorySpy()
        let token = try makeToken(store: store, id: "impression-1", placement: .banner)

        try await withDependencies {
            $0[AdvertisingEnvironmentKey.self] = AdvertisingEnvironment(environment: [
                "ADVERTISEMENT_IMPRESSION_TOKEN_SECRET": secret
            ])
            $0[StoreRepositoryKey.self] = StoreRepositorySpy(store: store)
            $0[ImpressionRepositoryKey.self] = charging
        } operation: {
            try await ImpressionUsecase().report(.init(
                impressionId: "impression-1", impressionToken: token
            ))
        }

        let charges = await charging.charges
        #expect(charges.count == 1)
        #expect(charges.first?.id == "impression-1")
        #expect(charges.first?.storeId == store.id)
        #expect(charges.first?.placement == .banner)
    }

    @Test("表示tokenのimpressionIdとリクエストのIDが異なる場合は課金しない")
    func mismatchedImpressionIDIsRejectedBeforeLookup() async throws {
        let store = makeStore()
        let charging = RecordingImpressionRepositorySpy()
        let token = try makeToken(store: store, id: "signed-id", placement: .banner)

        do {
            try await withDependencies {
                $0[AdvertisingEnvironmentKey.self] = AdvertisingEnvironment(environment: [
                    "ADVERTISEMENT_IMPRESSION_TOKEN_SECRET": secret
                ])
                $0[StoreRepositoryKey.self] = StoreRepositorySpy(store: store)
                $0[ImpressionRepositoryKey.self] = charging
            } operation: {
                try await ImpressionUsecase().report(.init(
                    impressionId: "different-id", impressionToken: token
                ))
            }
            Issue.record("署名された表示IDとの不一致が受け入れられた")
        } catch {
            #expect((error as? Application.Error)?.localizedDescription == "表示実績 token の対象が一致しません。")
        }
        #expect(await charging.charges.isEmpty)
    }

    @Test("署名された店舗が存在しなければ表示実績を消費しない")
    func missingStoreFailsWithoutCharging() async throws {
        let store = makeStore()
        let charging = RecordingImpressionRepositorySpy()
        let token = try makeToken(store: store, id: "impression-2", placement: .banner)

        do {
            try await withDependencies {
                $0[AdvertisingEnvironmentKey.self] = AdvertisingEnvironment(environment: [
                    "ADVERTISEMENT_IMPRESSION_TOKEN_SECRET": secret
                ])
                $0[StoreRepositoryKey.self] = StoreRepositorySpy()
                $0[ImpressionRepositoryKey.self] = charging
            } operation: {
                try await ImpressionUsecase().report(.init(
                    impressionId: "impression-2", impressionToken: token
                ))
            }
            Issue.record("存在しない店舗への表示実績が成功してしまった")
        } catch {
            #expect((error as? Application.Error)?.localizedDescription == "表示対象の店舗が見つかりません。")
        }
        #expect(await charging.charges.isEmpty)
    }

    @Test("非承認店舗・所有者停止中・広告画像未設定はそれぞれ課金しない")
    func inactiveStoreDoesNotCharge() async throws {
        let cases = [
            makeStore(moderationStatus: .suspended, interstitialImagePath: "https://cdn.example/full.jpg"),
            makeStore(ownerPaused: true, interstitialImagePath: "https://cdn.example/full.jpg"),
            makeStore()
        ]
        for (index, store) in cases.enumerated() {
            let charging = RecordingImpressionRepositorySpy()
            let impressionID = "impression-\(index)"
            let token = try makeToken(store: store, id: impressionID, placement: .interstitial)
            try await withDependencies {
                $0[AdvertisingEnvironmentKey.self] = AdvertisingEnvironment(environment: [
                    "ADVERTISEMENT_IMPRESSION_TOKEN_SECRET": secret
                ])
                $0[StoreRepositoryKey.self] = StoreRepositorySpy(store: store)
                $0[ImpressionRepositoryKey.self] = charging
            } operation: {
                try await ImpressionUsecase().report(.init(
                    impressionId: impressionID, impressionToken: token
                ))
            }
            #expect(await charging.charges.isEmpty)
        }
    }

    @Test("全画面広告の有効な表示はinterstitialとして課金を依頼する")
    func eligibleInterstitialIsCharged() async throws {
        let store = makeStore(interstitialImagePath: "https://cdn.example/full.jpg")
        let charging = RecordingImpressionRepositorySpy()
        let token = try makeToken(store: store, id: "impression-full", placement: .interstitial)
        try await withDependencies {
            $0[AdvertisingEnvironmentKey.self] = AdvertisingEnvironment(environment: [
                "ADVERTISEMENT_IMPRESSION_TOKEN_SECRET": secret
            ])
            $0[StoreRepositoryKey.self] = StoreRepositorySpy(store: store)
            $0[ImpressionRepositoryKey.self] = charging
        } operation: {
            try await ImpressionUsecase().report(.init(
                impressionId: "impression-full", impressionToken: token
            ))
        }
        let charges = await charging.charges
        #expect(charges.count == 1)
        #expect(charges.first?.placement == .interstitial)
    }

    @Test("無効な署名tokenは店舗参照前に拒否する")
    func invalidTokenCannotBeReported() async {
        let charging = RecordingImpressionRepositorySpy()
        do {
            try await withDependencies {
                $0[AdvertisingEnvironmentKey.self] = AdvertisingEnvironment(environment: [
                    "ADVERTISEMENT_IMPRESSION_TOKEN_SECRET": secret
                ])
                $0[StoreRepositoryKey.self] = StoreRepositorySpy()
                $0[ImpressionRepositoryKey.self] = charging
            } operation: {
                try await ImpressionUsecase().report(.init(
                    impressionId: "impression-4", impressionToken: "invalid"
                ))
            }
            Issue.record("不正なtokenが受け入れられた")
        } catch {
            #expect((error as? Application.Error)?.localizedDescription == "広告表示 token が不正です。")
        }
        #expect(await charging.charges.isEmpty)
    }

    private func makeStore(
        ownerPaused: Bool = false,
        moderationStatus: ModerationStatus = .approved,
        interstitialImagePath: String? = nil
    ) -> Store {
        Store(
            id: "store-1",
            festivalId: "festival-1",
            ownerId: "owner-1",
            purchaseAccountToken: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Cafe",
            businessHours: "",
            bannerImagePath: "https://cdn.example/banner.jpg",
            interstitialImagePath: interstitialImagePath,
            ownerPaused: ownerPaused,
            moderationStatus: moderationStatus
        )
    }

    private func makeToken(store: Store, id: String, placement: StoreAdPlacement) throws -> String {
        try ImpressionToken(secret: secret).sign(.init(
            impressionId: id,
            storeId: store.id,
            festivalId: store.festivalId,
            placement: placement,
            expiresAt: Date().addingTimeInterval(300)
        ))
    }
}

private actor RecordingImpressionRepositorySpy: ImpressionRepositoryProtocol {
    struct Charge: Sendable {
        let id: String
        let storeId: String
        let placement: StoreAdPlacement
    }

    private(set) var charges: [Charge] = []

    func charge(
        impressionId: String,
        storeId: Store.ID,
        placement: StoreAdPlacement,
        chargedAt: Date
    ) async throws -> ImpressionChargeResult {
        charges.append(.init(id: impressionId, storeId: storeId, placement: placement))
        return .charged
    }
}
