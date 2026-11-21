import Foundation
import Shared
import Testing

struct PeriodTests {
    @Test("Period carries editionId while retaining deprecated festivalId")
    func periodEncodesBothFestivalAndEditionIds() throws {
        let period = Period(
            id: "period-1",
            editionId: "edition-2027",
            festivalId: "festival-1",
            title: "Morning",
            date: SimpleDate(year: 2027, month: 5, day: 4),
            start: SimpleTime(hour: 9, minute: 30),
            end: SimpleTime(hour: 10, minute: 30)
        )

        let data = try JSONEncoder().encode(period)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["editionId"] as? String == "edition-2027")
        #expect(object["festivalId"] as? String == "festival-1")
        #expect(try JSONDecoder().decode(Period.self, from: data) == period)
    }

    @Test("Deprecated Period initializer keeps legacy periods representable")
    func deprecatedInitializerLeavesEditionUnset() {
        let period = Period(id: "legacy-period", festivalId: "festival-1", date: SimpleDate(year: 2026, month: 5, day: 4))

        #expect(period.festivalId == "festival-1")
        #expect(period.editionId == nil)
    }
}
