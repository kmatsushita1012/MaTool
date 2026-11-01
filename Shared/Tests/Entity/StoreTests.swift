import Foundation
import Shared
import Testing

struct StoreTests {
    @Test("Synthesized Codable keeps nullable image fields as JSON null")
    func nullableFieldsEncodeAsNullAndDecode() throws {
        let store = Store(
            id: "store-1",
            festivalId: "festival-1",
            ownerId: "owner-1",
            purchaseAccountToken: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Store",
            address: "Address",
            coordinate: Coordinate(latitude: 35, longitude: 139),
            businessHours: ""
        )
        let data = try JSONEncoder().encode(store)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["description"] is NSNull)
        #expect(object["bannerImagePath"] is NSNull)
        #expect(object["interstitialImagePath"] is NSNull)
        #expect(try JSONDecoder().decode(Store.self, from: data) == store)
    }
}
