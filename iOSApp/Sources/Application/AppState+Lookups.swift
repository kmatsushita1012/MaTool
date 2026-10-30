import Foundation
import Shared

extension AppState {
    func district(id: District.ID) -> District? {
        festivalState.districts.first { $0.id == id }
    }

    var districtsById: [District.ID: District] {
        festivalState.districts.reduce(into: [:]) { result, district in
            if result[district.id] == nil {
                result[district.id] = district
            }
        }
    }

    var selectedDistrict: District? {
        guard let districtState else { return nil }
        return district(id: districtState.districtId)
    }

    func period(id: Period.ID) -> Period? {
        festivalState.periods.first { $0.id == id }
    }

    func routeState(for routeId: Route.ID?) -> RouteState? {
        guard let routeId,
              let routeState,
              routeState.route.id == routeId else { return nil }
        return routeState
    }

    func currentPeriod(at date: Date) -> Period? {
        festivalState.periods.first { $0.contains(date) }
    }

    func checkpoint(id: Checkpoint.ID?) -> Checkpoint? {
        guard let id else { return nil }
        return festivalState.checkpoints.first { $0.id == id }
    }

    func performance(id: Performance.ID?, districtId: District.ID) -> Performance? {
        guard let id,
              let districtState,
              districtState.districtId == districtId else { return nil }
        return districtState.performances.first { $0.id == id }
    }

    func floatLocation(for districtId: District.ID) -> FloatLocation? {
        festivalState.floatLocations.first { $0.districtId == districtId }
    }

    var floatEntries: [FloatEntry] {
        festivalState.floatLocations.compactMap { location in
            guard let district = district(id: location.districtId) else { return nil }
            return FloatEntry(floatLocation: location, district: district)
        }
    }

    func floatEntry(for districtId: District.ID) -> FloatEntry? {
        guard let location = floatLocation(for: districtId),
              let district = district(id: districtId) else { return nil }
        return FloatEntry(floatLocation: location, district: district)
    }

    func routeDistrictIds(prioritizing districtId: District.ID?) -> [District.ID] {
        let sortedDistricts = festivalState.districts.sorted { lhs, rhs in
            let groupOrder = (lhs.group ?? "").localizedStandardCompare(rhs.group ?? "")
            if groupOrder != .orderedSame {
                return groupOrder == .orderedAscending
            }
            let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
            return lhs.id < rhs.id
        }

        guard let districtId,
              let selectedDistrict = sortedDistricts.first(where: { $0.id == districtId }) else {
            return sortedDistricts.map(\.id)
        }

        let sameGroup = sortedDistricts.filter {
            $0.id != selectedDistrict.id && $0.group == selectedDistrict.group
        }
        let otherGroups = sortedDistricts.filter { $0.group != selectedDistrict.group }
        return ([selectedDistrict] + sameGroup + otherGroups).map(\.id)
    }

    func routeEntries(for districtId: District.ID) -> [RouteEntry] {
        guard let districtState,
              districtState.districtId == districtId else { return [] }
        return districtState.routes.compactMap { route in
            guard let period = period(id: route.periodId) else { return nil }
            return RouteEntry(period: period, route: route)
        }.sorted()
    }

    func routeEntry(id: Route.ID?, districtId: District.ID) -> RouteEntry? {
        guard let id,
              let districtState,
              districtState.districtId == districtId,
              let route = districtState.routes.first(where: { $0.id == id }),
              let period = period(id: route.periodId) else { return nil }
        return RouteEntry(period: period, route: route)
    }

    func pointEntries(for routeId: Route.ID, districtId: District.ID) -> [PointEntry] {
        guard let districtState,
              districtState.districtId == districtId,
              let routeState,
              routeState.route.id == routeId else { return [] }
        return pointEntries(for: routeState.points, districtId: districtId).sorted {
            $0.point < $1.point
        }
    }

    func pointEntries(for points: [Point], districtId: District.ID) -> [PointEntry] {
        return points.map { point in
            PointEntry(
                point,
                checkpoint: checkpoint(id: point.checkpointId),
                performance: performance(id: point.performanceId, districtId: districtId)
            )
        }
    }
}

extension DistrictState {
    func route(id: Route.ID) -> Route? {
        routes.first { $0.id == id }
    }

    mutating func upsertRoute(_ route: Route) {
        if let index = routes.firstIndex(where: { $0.id == route.id }) {
            routes[index] = route
        } else {
            routes.append(route)
        }
    }

    mutating func removeRoute(id: Route.ID) {
        routes.removeAll { $0.id == id }
    }

    mutating func removeRoutes(outside periodIds: Set<Period.ID>) {
        routes.removeAll { !periodIds.contains($0.periodId) }
    }
}

extension FestivalState {
    func containsDistrict(id: District.ID) -> Bool {
        districts.contains { $0.id == id }
    }

    mutating func replaceDistrict(_ district: District) {
        guard let index = districts.firstIndex(where: { $0.id == district.id }) else { return }
        districts[index] = district
    }

    mutating func upsertDistrict(_ district: District) {
        if let index = districts.firstIndex(where: { $0.id == district.id }) {
            districts[index] = district
        } else {
            districts.append(district)
        }
    }

    mutating func upsertPeriod(_ period: Period) {
        periods.removeAll { $0.id == period.id }
        guard period.date.year == year else { return }
        periods.append(period)
        periods.sort()
    }

    mutating func removePeriod(id: Period.ID) {
        periods.removeAll { $0.id == id }
    }

    mutating func upsertFloatLocation(_ location: FloatLocation) {
        floatLocations.removeAll { $0.districtId == location.districtId }
        floatLocations.append(location)
    }

    mutating func removeFloatLocation(for districtId: District.ID) {
        floatLocations.removeAll { $0.districtId == districtId }
    }

    mutating func replaceFloatLocations(with locations: [FloatLocation]) {
        var latestByDistrict: [District.ID: FloatLocation] = [:]
        for location in locations {
            if let existing = latestByDistrict[location.districtId],
               existing.timestamp >= location.timestamp {
                continue
            }
            latestByDistrict[location.districtId] = location
        }
        floatLocations = districts.compactMap { latestByDistrict[$0.id] }
    }
}
