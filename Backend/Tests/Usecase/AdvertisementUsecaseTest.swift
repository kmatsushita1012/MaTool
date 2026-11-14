import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct AdvertisementUsecaseTest {
    @Test("住所と座標がない店舗も広告配信候補になる")
    func nextIncludesStoreWithoutLocation() async throws {
        let store = Store(
            id: "store-1",
            festivalId: "festival-1",
            ownerId: "owner-1",
            purchaseAccountToken: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Cafe",
            businessHours: "",
            bannerImagePath: "https://cdn.example/banner.jpg"
        )
        let festival = Festival(
            id: "festival-1",
            name: "Festival",
            subname: "",
            base: Coordinate(latitude: 35, longitude: 139)
        )

        let candidate = try await withDependencies {
            $0[StoreRepositoryKey.self] = StoreRepositorySpy(store: store)
            $0[CreditRepositoryKey.self] = CreditRepositorySpy(account: CreditAccount(storeId: store.id, balance: 1))
            $0[FestivalRepositoryKey.self] = FestivalRepositorySpy(festivals: [festival])
            $0[AdvertisingEnvironmentKey.self] = AdvertisingEnvironment(environment: [
                "ADVERTISEMENT_IMPRESSION_TOKEN_SECRET": String(repeating: "s", count: 32)
            ])
        } operation: {
            try await AdvertisementUsecase().next(festivalId: festival.id, placement: .banner)
        }

        #expect(candidate?.storeId == store.id)
        #expect(candidate?.imagePath == store.bannerImagePath)
    }
    @Test("存在しない祭典では広告候補を取得せずnotFoundを返す")
    func unknownFestivalIsRejected() async {
        do {
            _ = try await withDependencies {
                $0[FestivalRepositoryKey.self] = FestivalRepositorySpy()
            } operation: {
                try await AdvertisementUsecase().next(festivalId: "missing", placement: .banner)
            }
            Issue.record("存在しない祭典から広告が返された")
        } catch {
            #expect((error as? Application.Error)?.localizedDescription == "指定された祭典が見つかりません。")
        }
    }

    @Test("残高が配信費用未満なら広告候補には含めない")
    func insufficientBalancePreventsAdDelivery() async throws {
        let store = advertisementStore()
        let festival = advertisementFestival()
        let candidate = try await withDependencies {
            $0[StoreRepositoryKey.self] = StoreRepositorySpy(store: store)
            $0[CreditRepositoryKey.self] = CreditRepositorySpy(account: CreditAccount(storeId: store.id, balance: 0))
            $0[FestivalRepositoryKey.self] = FestivalRepositorySpy(festivals: [festival])
        } operation: {
            try await AdvertisementUsecase().next(festivalId: festival.id, placement: .banner)
        }
        #expect(candidate == nil)
    }

    @Test("停止中の店舗や配信画像のない店舗は残高があっても広告候補にしない")
    func pausedOrImagelessStoreIsNotEligible() async throws {
        let festival = advertisementFestival()
        var paused = advertisementStore()
        paused.ownerPaused = true
        var noImage = advertisementStore()
        noImage.bannerImagePath = nil
        for store in [paused, noImage] {
            let candidate = try await withDependencies {
                $0[StoreRepositoryKey.self] = StoreRepositorySpy(store: store)
                $0[CreditRepositoryKey.self] = CreditRepositorySpy(account: CreditAccount(storeId: store.id, balance: 100))
                $0[FestivalRepositoryKey.self] = FestivalRepositorySpy(festivals: [festival])
            } operation: {
                try await AdvertisementUsecase().next(festivalId: festival.id, placement: .banner)
            }
            #expect(candidate == nil)
        }
    }

    @Test("全画面広告の候補には画像・2Credit・署名されたinterstitial tokenが必要")
    func interstitialUsesCorrectImageAndCreditCost() async throws {
        let store = advertisementStore(interstitialImagePath: "https://cdn.example/full.jpg")
        let festival = advertisementFestival()
        let candidate = try await withDependencies {
            $0[StoreRepositoryKey.self] = StoreRepositorySpy(store: store)
            $0[CreditRepositoryKey.self] = CreditRepositorySpy(account: CreditAccount(storeId: store.id, balance: 2))
            $0[FestivalRepositoryKey.self] = FestivalRepositorySpy(festivals: [festival])
            $0[AdvertisingEnvironmentKey.self] = AdvertisingEnvironment(environment: [
                "ADVERTISEMENT_IMPRESSION_TOKEN_SECRET": String(repeating: "s", count: 32)
            ])
        } operation: {
            try await AdvertisementUsecase().next(festivalId: festival.id, placement: .interstitial)
        }

        let ad = try #require(candidate)
        #expect(ad.placement == .interstitial)
        #expect(ad.imagePath == "https://cdn.example/full.jpg")
        let payload = try ImpressionToken(secret: String(repeating: "s", count: 32)).verify(ad.impressionToken)
        #expect(payload.impressionId == ad.impressionId)
        #expect(payload.storeId == store.id)
        #expect(payload.placement == .interstitial)
    }

    @Test("空文字と1000字超の通報理由は店舗検索前に拒否する")
    func invalidReportsAreRejectedBeforeLookup() async {
        for reason in ["  ", String(repeating: "x", count: 1_001)] {
            do {
                try await AdvertisementUsecase().report(.init(storeId: "store-1", reason: reason))
                Issue.record("無効な通報理由が許可された")
            } catch {
                #expect((error as? Application.Error)?.localizedDescription == "通報理由は1〜1000文字で入力してください。")
            }
        }
    }

    @Test("通報対象の店舗が存在しない場合は通知を送信しない")
    func missingReportedStoreIsRejected() async {
        let notices = ReportNotificationSpy()
        do {
            try await withDependencies {
                $0[StoreRepositoryKey.self] = StoreRepositorySpy()
                $0[ReportNotificationClientKey.self] = notices
            } operation: {
                try await AdvertisementUsecase().report(.init(storeId: "missing", reason: "不適切な内容"))
            }
            Issue.record("存在しない店舗への通報が受け入れられた")
        } catch {
            #expect((error as? Application.Error)?.localizedDescription == "通報対象の店舗が見つかりません。")
        }
        #expect(await notices.requests.isEmpty)
    }

    @Test("正常な通報理由は前後空白を除き、対象店舗・祭典情報とともに一度だけ通知する")
    func reportTrimsAndNotifiesOnce() async throws {
        let store = advertisementStore()
        let notices = ReportNotificationSpy()
        try await withDependencies {
            $0[StoreRepositoryKey.self] = StoreRepositorySpy(store: store)
            $0[ReportNotificationClientKey.self] = notices
        } operation: {
            try await AdvertisementUsecase().report(.init(
                storeId: store.id, placement: .banner, reason: "  不適切な表示  "
            ))
        }

        let sent = await notices.requests
        #expect(sent.count == 1)
        #expect(sent.first?.storeId == store.id)
        #expect(sent.first?.festivalId == store.festivalId)
        #expect(sent.first?.placement == .banner)
        #expect(sent.first?.reason == "不適切な表示")
    }

    private func advertisementFestival() -> Festival {
        Festival(
            id: "festival-1",
            name: "Festival",
            subname: "",
            base: Coordinate(latitude: 35, longitude: 139)
        )
    }

    private func advertisementStore(interstitialImagePath: String? = nil) -> Store {
        Store(
            id: "store-1",
            festivalId: "festival-1",
            ownerId: "owner-1",
            purchaseAccountToken: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Cafe",
            businessHours: "",
            bannerImagePath: "https://cdn.example/banner.jpg",
            interstitialImagePath: interstitialImagePath
        )
    }

}

private actor ReportNotificationSpy: ReportNotificationClientProtocol {
    struct Request: Sendable {
        let storeId: Store.ID
        let festivalId: Festival.ID
        let placement: StoreAdPlacement?
        let reason: String
    }

    private(set) var requests: [Request] = []

    func notify(
        storeId: Store.ID,
        festivalId: Festival.ID,
        placement: StoreAdPlacement?,
        reason: String,
        receivedAt: Date
    ) async throws {
        requests.append(.init(
            storeId: storeId, festivalId: festivalId, placement: placement, reason: reason
        ))
    }
}
