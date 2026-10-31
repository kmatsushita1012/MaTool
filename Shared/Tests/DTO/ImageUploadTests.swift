import Foundation
import Testing
@testable import Shared

struct ImageUploadTests {
    @Test func requestUsesSharedWireFormat() throws {
        let request = ImageUploadURLRequest(
            target: .init(type: .festival, id: "festival-001", variant: .light),
            contentType: "image/jpeg"
        )
        let data = try JSONEncoder().encode(request)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let target = try #require(json["target"] as? [String: String])
        #expect(target == ["type": "festival", "id": "festival-001", "variant": "light"])
        #expect(json["contentType"] as? String == "image/jpeg")
        #expect(try JSONDecoder().decode(ImageUploadURLRequest.self, from: data) == request)
    }
}
