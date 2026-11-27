import Foundation
import Shared
import Testing

struct PeriodTests {
    @Test("Period wire format contains editionId without the legacy festivalId")
    func periodEncodesEditionIdOnly() throws {
        let period = Period(
            id: "period-1",
            editionId: "edition-2027",
            title: "Morning",
            date: SimpleDate(year: 2027, month: 5, day: 4),
            start: SimpleTime(hour: 9, minute: 30),
            end: SimpleTime(hour: 10, minute: 30)
        )

        let data = try JSONEncoder().encode(period)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["editionId"] as? String == "edition-2027")
        #expect(object["festivalId"] == nil)
        #expect(try JSONDecoder().decode(Period.self, from: data) == period)
    }
}
