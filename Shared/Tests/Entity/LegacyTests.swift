import Foundation
@testable import Shared
import Testing

struct LegacyTests {
    @Test("Deprecated legacy conversion keeps the festival ID")
    func spanConvertsToLegacyPeriod() {
        let span = Legacy.Span(
            id: "period-legacy",
            start: Date(timeIntervalSince1970: 1_778_472_000),
            end: Date(timeIntervalSince1970: 1_778_475_600)
        )

        let period = span.toPeriod(festivalId: "festival-1")

        #expect(period.id == "period-legacy")
        #expect(period.festivalId == "festival-1")
        #expect(period.editionId == nil)
    }

    @Test("Legacy span conversion assigns the supplied edition")
    func spanConvertsToPeriodInEdition() {
        let span = Legacy.Span(
            id: "period-1",
            start: Date(timeIntervalSince1970: 1_778_472_000),
            end: Date(timeIntervalSince1970: 1_778_475_600)
        )

        let period = span.toPeriod(festivalId: "festival-1", editionId: "edition-2027")

        #expect(period.id == "period-1")
        #expect(period.editionId == "edition-2027")
        #expect(period.festivalId == "festival-1")
    }
}
