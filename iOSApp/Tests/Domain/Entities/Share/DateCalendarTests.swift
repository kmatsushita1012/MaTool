import Foundation
import Testing
import Shared
@testable import iOSApp

struct iOSAppDateCalendarTests {
    @Test
    func sameWeekdayは日本時間のグレゴリオ暦で同じ第何週何曜日を返す() async throws {
        let source = SimpleDate(year: 2025, month: 10, day: 11).toDate

        let shifted = try #require(source.sameWeekday(in: 2026))
        let result = Calendar.japanGregorian.dateComponents([.year, .month, .day, .weekday], from: shifted)

        #expect(result.year == 2026)
        #expect(result.month == 10)
        #expect(result.day == 10)
        #expect(result.weekday == 7)
    }
}
