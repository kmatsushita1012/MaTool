import Foundation
import Shared
import Testing

struct EditionDTOTests {
    @Test("Edition list represents a missing active edition as JSON null")
    func editionListEncodesNilActiveEditionAsNull() throws {
        let response = EditionListResponse(editions: [], activeEditionId: nil)

        let data = try JSONEncoder().encode(response)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect((object["editions"] as? [Any])?.isEmpty == true)
        #expect(object["activeEditionId"] is NSNull)
        #expect(try JSONDecoder().decode(EditionListResponse.self, from: data) == response)
    }

    @Test("Edition forms encode their declared fields")
    func editionFormsRoundTrip() throws {
        let createForm = EditionCreateForm(year: 2027)
        let updateForm = ActiveEditionUpdateForm(editionId: "edition-2027")

        let createData = try JSONEncoder().encode(createForm)
        let createObject = try #require(JSONSerialization.jsonObject(with: createData) as? [String: Any])
        #expect(Set(createObject.keys) == ["year"])
        #expect(try JSONDecoder().decode(EditionCreateForm.self, from: createData) == createForm)

        let updateData = try JSONEncoder().encode(updateForm)
        let updateObject = try #require(JSONSerialization.jsonObject(with: updateData) as? [String: Any])
        #expect(Set(updateObject.keys) == ["editionId"])
        #expect(try JSONDecoder().decode(ActiveEditionUpdateForm.self, from: updateData) == updateForm)
    }
}
