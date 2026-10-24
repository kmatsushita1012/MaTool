import Shared

extension FestivalState {
    func routeSlots(for routes: [Route]) -> [RouteSlot] {
        let routesByPeriodId = Dictionary(grouping: routes, by: \.periodId)
        return periods.map { period in
            RouteSlot(period: period, route: routesByPeriodId[period.id]?.first)
        }
    }
}

extension AppState {
    func routeSlots(
        for districtId: District.ID,
        routeOverrides: [Route.ID: Route] = [:]
    ) -> [RouteSlot] {
        guard let districtState, districtState.districtId == districtId else { return [] }
        return festivalState.routeSlots(for: districtState.routes).map { slot in
            guard let route = slot.route,
                  let override = routeOverrides[route.id] else { return slot }
            return RouteSlot(period: slot.period, route: override)
        }
    }
}
