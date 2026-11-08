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
}
