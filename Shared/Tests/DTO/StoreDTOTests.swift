import Foundation
import Shared
import Testing

struct StoreDTOTests {
    @Test("StoreCreateRequest encodes an omitted description as null")
    func optionalDescriptionIsExplicitlyNull() throws {
        let dto = StoreCreateRequest(
            name: "Store",
            address: "Address",
            coordinate: Coordinate(latitude: 35, longitude: 139),
            businessHours: ""
        )
        let data = try JSONEncoder().encode(dto)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["description"] is NSNull)
        #expect(try JSONDecoder().decode(StoreCreateRequest.self, from: data).name == dto.name)
    }
}
