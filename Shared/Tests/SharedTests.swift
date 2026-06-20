//
//  SharedTests.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

import Testing
import Foundation
@testable import Shared

struct SharedDateTimeTests {
    @Test
    func simpleDate_weekdayは日本時間のグレゴリオ暦で計算する() {
        let date = SimpleDate(year: 2020, month: 10, day: 10)

        #expect(date.weekday == 7)
    }

    @Test
    func simpleDate_toDateとfromは日本時間で往復できる() {
        let original = SimpleDate(year: 2020, month: 10, day: 10)
        let restored = SimpleDate.from(original.toDate)

        #expect(restored == original)
    }

    @Test
    func japanGregorianは東京のグレゴリオ暦を返す() {
        let calendar = Calendar.japanGregorian

        #expect(calendar.identifier == .gregorian)
        #expect(calendar.timeZone.identifier == "Asia/Tokyo")
    }
}
