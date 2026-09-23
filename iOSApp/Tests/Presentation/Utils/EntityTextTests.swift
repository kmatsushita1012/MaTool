import Testing
import Shared
@testable import iOSApp

struct EntityTextTests {
    @Test
    func PublicRouteの日程pickerは日付曜日タイトルを表示する() {
        let period = Period(
            id: "period-1",
            festivalId: "festival-1",
            title: "夜",
            date: SimpleDate(year: 2023, month: 10, day: 9)
        )
        let route = Route(
            id: "route-1",
            districtId: "district-1",
            periodId: period.id
        )
        let entry = RouteEntry(period: period, route: route)

        #expect(entry.text == "10/9（月）夜")
    }
}
