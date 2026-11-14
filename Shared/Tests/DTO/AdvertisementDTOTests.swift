import Foundation
import Shared
import Testing

struct AdvertisementDTOTests {
    @Test("公開 Store DTO は停止中の画像を null にし内部情報を返さない")
    func publicStoreHidesImagesAndPrivateFields() throws {
        let store = Store(
            id: "store-1",
            festivalId: "festival-1",
            ownerId: "private-owner",
            purchaseAccountToken: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Store",
            address: "Address",
            coordinate: Coordinate(latitude: 35, longitude: 139),
            businessHours: "",
            bannerImagePath: "https://cdn.example/banner.jpg"
        )
        let dto = PublicStore(store: store, hideImages: true)
        let data = try JSONEncoder().encode(dto)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["bannerImagePath"] is NSNull)
        #expect(object["ownerId"] == nil)
        #expect(object["purchaseAccountToken"] == nil)
    }
}
