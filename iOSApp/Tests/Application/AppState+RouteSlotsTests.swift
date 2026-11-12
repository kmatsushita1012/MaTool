import Shared
import Testing
@testable import iOSApp

struct AppStateRouteSlotsTests {
    @Test("期間順を維持し、ルートのない期間も空き枠として返す")
    func ordersSlotsAndRetainsMissingRoutes() {
        let first = AppStateFixture.period(id: "first", day: 3)
        let second = AppStateFixture.period(id: "second", day: 4)
        let secondRoute = AppStateFixture.route(id: "second-route", periodId: second.id)
        let state = AppStateFixture.state(periods: [first, second], routes: [secondRoute])

        let slots = state.routeSlots(for: "district")

        #expect(slots.map(\.period.id) == ["first", "second"])
        #expect(slots[0].route == nil)
        #expect(slots[1].route == secondRoute)
    }

    @Test("同一期間に複数ルートがあれば先頭を使用する")
    func usesFirstRouteForDuplicatePeriods() {
        let first = AppStateFixture.route(id: "first")
        let second = AppStateFixture.route(id: "second")
        let state = AppStateFixture.state(routes: [first, second])

        #expect(state.routeSlots(for: "district").map(\.route?.id) == ["first"])
    }

    @Test("別地区と未選択の地区に対してはルート枠を返さない")
    func avoidsUnrelatedDistricts() {
        let state = AppStateFixture.state(routes: [AppStateFixture.route()])
        let withoutDistrict = AppStateFixture.state(selectedDistrictId: nil)

        #expect(state.routeSlots(for: "unrelated").isEmpty)
        #expect(withoutDistrict.routeSlots(for: "district").isEmpty)
    }

    @Test("指定ルートのみ上書きし、未指定ルートには影響しない")
    func overridesOnlyMatchedRoute() {
        let original = AppStateFixture.route(description: "original")
        let replacement = AppStateFixture.route(description: "edited")
        let state = AppStateFixture.state(routes: [original])

        #expect(state.routeSlots(for: "district").first?.route == original)
        #expect(state.routeSlots(for: "district", routeOverrides: ["unrelated": replacement])
            .first?.route == original)
        #expect(state.routeSlots(for: "district", routeOverrides: [original.id: replacement])
            .first?.route == replacement)
    }
}
