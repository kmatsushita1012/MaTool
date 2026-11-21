import Foundation
import Shared
import Testing

struct EditionPackTests {
    @Test("EditionPack round-trips edition and its periods")
    func editionPackRoundTrips() throws {
        let edition = Edition(id: "edition-2027", festivalId: "festival-1", year: 2027)
        let period = Period(
            id: "period-1",
            editionId: edition.id,
            festivalId: edition.festivalId,
            date: SimpleDate(year: 2027, month: 5, day: 4)
        )
        let pack = EditionPack(edition: edition, periods: [period])

        let data = try JSONEncoder().encode(pack)
        let decodedPack = try JSONDecoder().decode(EditionPack.self, from: data)

        #expect(decodedPack == pack)
        #expect(decodedPack.periods.first?.editionId == edition.id)
    }
}
