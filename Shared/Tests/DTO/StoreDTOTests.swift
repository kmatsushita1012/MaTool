import Foundation
import Shared
import Testing

struct StoreDTOTests {
    @Test("StoreCreateRequest treats missing location keys as nil and encodes them as null")
    func missingLocationKeysRoundTripAsNull() throws {
        let requestBody = Data(#"{"name":"Cafe","businessHours":""}"#.utf8)
        let decodedRequest = try JSONDecoder().decode(StoreCreateRequest.self, from: requestBody)

        #expect(decodedRequest.address == nil)
        #expect(decodedRequest.coordinate == nil)

        let data = try JSONEncoder().encode(decodedRequest)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["address"] is NSNull)
        #expect(object["coordinate"] is NSNull)
        #expect(object["description"] is NSNull)
        #expect(try JSONDecoder().decode(StoreCreateRequest.self, from: data) == decodedRequest)
    }

    @Test("PublicStore encodes and decodes nullable location")
    func publicStoreRoundTripsNullableLocation() throws {
        let store = makeStore(address: nil, coordinate: nil)
        let publicStore = PublicStore(store: store, hideImages: false)
        let data = try JSONEncoder().encode(publicStore)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["address"] is NSNull)
        #expect(object["coordinate"] is NSNull)
        #expect(try JSONDecoder().decode(PublicStore.self, from: data) == publicStore)
    }

    private func makeStore(address: String?, coordinate: Coordinate?) -> Store {
        Store(
            id: "store-1",
            festivalId: "festival-1",
            ownerId: "owner-1",
            purchaseAccountToken: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Cafe",
            address: address,
            coordinate: coordinate,
            businessHours: ""
        )
    }
}
