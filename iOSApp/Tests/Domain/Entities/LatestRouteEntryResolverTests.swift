import Shared
import Testing
@testable import iOSApp

struct LatestRouteEntryResolverTests {
    @Test
    func 最新年度にRouteがない場合はBackendと同じ候補年度のRouteを選ぶ() {
        let currentPeriod = Period(
            id: "period-current",
            festivalId: "festival-1",
            date: SimpleDate(year: 2026, month: 10, day: 3)
        )
        let previousPeriod = Period(
            id: "period-previous",
            festivalId: "festival-1",
            date: SimpleDate(year: 2025, month: 10, day: 3)
        )
        let previousRoute = Route(
            id: "route-previous",
            districtId: "district-1",
            periodId: previousPeriod.id
        )

        let result = LatestRouteEntryResolver.resolve(
            periods: [currentPeriod, previousPeriod],
            routes: [RouteEntry(period: previousPeriod, route: previousRoute)],
            nowYear: 2026
        )

        #expect(result.year == 2025)
        #expect(result.periods.map(\.id) == [currentPeriod.id, previousPeriod.id])
    }

    @Test
    func 翌年度Periodがある場合は今年度Routeを優先する() {
        let nextPeriod = Period(
            id: "period-next",
            festivalId: "festival-1",
            date: SimpleDate(year: 2027, month: 10, day: 3)
        )
        let currentPeriod = Period(
            id: "period-current",
            festivalId: "festival-1",
            date: SimpleDate(year: 2026, month: 10, day: 3)
        )
        let currentRoute = Route(
            id: "route-current",
            districtId: "district-1",
            periodId: currentPeriod.id
        )

        let result = LatestRouteEntryResolver.resolve(
            periods: [nextPeriod, currentPeriod],
            routes: [RouteEntry(period: currentPeriod, route: currentRoute)],
            nowYear: 2026
        )

        #expect(result.year == 2026)
        #expect(result.periods.map(\.id) == [nextPeriod.id, currentPeriod.id])
    }
}
