import Foundation
import Shared
import Testing

struct EditionTests {
    @Test("Edition and ActiveEdition preserve their declared JSON fields")
    func editionModelsRoundTrip() throws {
        let edition = Edition(id: "edition-2027", festivalId: "festival-1", year: 2027)
        let activeEdition = ActiveEdition(festivalId: "festival-1", editionId: edition.id)

        let editionData = try JSONEncoder().encode(edition)
        let editionObject = try #require(JSONSerialization.jsonObject(with: editionData) as? [String: Any])
        #expect(Set(editionObject.keys) == ["id", "festivalId", "year"])
        #expect(try JSONDecoder().decode(Edition.self, from: editionData) == edition)

        let activeEditionData = try JSONEncoder().encode(activeEdition)
        let activeEditionObject = try #require(JSONSerialization.jsonObject(with: activeEditionData) as? [String: Any])
        #expect(Set(activeEditionObject.keys) == ["festivalId", "editionId"])
        #expect(try JSONDecoder().decode(ActiveEdition.self, from: activeEditionData) == activeEdition)
    }
}
