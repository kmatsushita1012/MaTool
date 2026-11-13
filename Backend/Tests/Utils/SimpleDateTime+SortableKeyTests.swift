import Shared
import Testing
@testable import Backend

struct SimpleDateTimeSortableKeyTests {
    @Test("一桁の月日と時分をゼロ埋めして並べ替え可能なキーにする")
    func zeroPadsSingleDigitComponents() {
        #expect(SimpleDate(year: 2026, month: 1, day: 9).sortableKey == "2026-01-09")
        #expect(SimpleTime(hour: 0, minute: 5).sortableKey == "00-05")
    }

    @Test("二桁の値を欠落や余計なゼロ埋めなく表現する")
    func preservesTwoDigitComponents() {
        #expect(SimpleDate(year: 2026, month: 12, day: 31).sortableKey == "2026-12-31")
        #expect(SimpleTime(hour: 23, minute: 59).sortableKey == "23-59")
    }

    @Test("同じ年の日付と同じ日の時刻を文字列順で並べ替えられる")
    func lexicographicOrderMatchesChronologicalOrder() {
        let dates = [
            SimpleDate(year: 2026, month: 10, day: 1),
            SimpleDate(year: 2026, month: 2, day: 10),
            SimpleDate(year: 2026, month: 10, day: 2),
        ]
        let times = [
            SimpleTime(hour: 12, minute: 0),
            SimpleTime(hour: 9, minute: 59),
            SimpleTime(hour: 12, minute: 1),
        ]

        #expect(dates.map(\.sortableKey).sorted() == ["2026-02-10", "2026-10-01", "2026-10-02"])
        #expect(times.map(\.sortableKey).sorted() == ["09-59", "12-00", "12-01"])
    }
}
