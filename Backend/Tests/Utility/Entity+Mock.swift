import Foundation
import Shared

extension Festival {
    static func mock(
        id: String = "festival-id",
        name: String = "festival-name",
        subname: String = "festival-sub",
        prefecture: String = "tokyo",
        city: String = "chiyoda",
        base: Coordinate = .init(latitude: 35.0, longitude: 139.0)
    ) -> Self {
        .init(id: id, name: name, subname: subname, prefecture: prefecture, city: city, base: base)
    }
}

extension Checkpoint {
    static func mock(
        id: String = "checkpoint-id",
        festivalId: Festival.ID = "festival-id",
        name: String = "checkpoint"
    ) -> Self {
        .init(id: id, name: name, festivalId: festivalId)
    }
}

extension HazardSection {
    static func mock(
        id: String = "hazard-id",
        festivalId: Festival.ID = "festival-id",
        title: String = "hazard",
        coordinates: [Coordinate] = []
    ) -> Self {
        .init(id: id, title: title, festivalId: festivalId, coordinates: coordinates)
    }
}

extension District {
    static func mock(
        id: String = "district-id",
        festivalId: Festival.ID = "festival-id",
        name: String = "district-name",
        visibility: Visibility = .all
    ) -> Self {
        .init(id: id, name: name, festivalId: festivalId, visibility: visibility)
    }
}

extension Performance {
    static func mock(
        id: String = "performance-id",
        districtId: District.ID = "district-id",
        name: String = "performance"
    ) -> Self {
        .init(id: id, name: name, districtId: districtId)
    }
}

extension FloatLocation {
    static func mock(
        id: String = "location-id",
        districtId: District.ID = "district-id",
        coordinate: Coordinate = .init(latitude: 35.0, longitude: 139.0),
        timestamp: Date = .init(timeIntervalSince1970: 1_700_000_000)
    ) -> Self {
        .init(id: id, districtId: districtId, coordinate: coordinate, timestamp: timestamp)
    }
}

extension Period {
    static func mock(
        id: String = "period-id",
        festivalId: Festival.ID = "festival-id",
        title: String = "period",
        date: SimpleDate = .init(year: 2026, month: 2, day: 22),
        start: SimpleTime = .init(hour: 9, minute: 0),
        end: SimpleTime = .init(hour: 18, minute: 0)
    ) -> Self {
        .init(id: id, festivalId: festivalId, title: title, date: date, start: start, end: end)
    }
}

extension Route {
    static func mock(
        id: String = "route-id",
        districtId: District.ID = "district-id",
        periodId: Period.ID = "period-id",
        visibility: Visibility = .all
    ) -> Self {
        .init(id: id, districtId: districtId, periodId: periodId, visibility: visibility)
    }
}

extension Point {
    static func mock(
        id: String = "point-id",
        routeId: Route.ID = "route-id",
        coordinate: Coordinate = .init(latitude: 35.0, longitude: 139.0),
        index: Int = 0,
        time: SimpleTime? = nil,
        checkpointId: Checkpoint.ID? = nil,
        performanceId: Performance.ID? = nil,
        anchor: Anchor? = nil,
        isBoundary: Bool = false
    ) -> Self {
        .init(
            id: id,
            routeId: routeId,
            coordinate: coordinate,
            time: time,
            checkpointId: checkpointId,
            performanceId: performanceId,
            anchor: anchor,
            index: index,
            isBoundary: isBoundary
        )
    }
}

extension RoutePassage {
    static func mock(
        id: String = "passage-id",
        routeId: Route.ID = "route-id",
        districtId: District.ID? = "district-id",
        memo: String? = nil,
        order: Int = 0
    ) -> Self {
        .init(id: id, routeId: routeId, districtId: districtId, memo: memo, order: order)
    }
}

extension FestivalPack {
    static func mock(
        festival: Festival = .mock(),
        checkpoints: [Checkpoint] = [],
        hazardSections: [HazardSection] = []
    ) -> Self {
        .init(festival: festival, checkpoints: checkpoints, hazardSections: hazardSections)
    }
}

extension DistrictPack {
    static func mock(
        district: District = .mock(),
        performances: [Performance] = []
    ) -> Self {
        .init(district: district, performances: performances)
    }
}

extension RoutePack {
    static func mock(
        route: Route = .mock(),
        points: [Point] = [],
        passages: [RoutePassage] = []
    ) -> Self {
        .init(route: route, points: points, passages: passages)
    }
}

extension LaunchFestivalPack {
    static func mock(
        festival: Festival = .mock(),
        districts: [District] = [],
        periods: [Period] = [],
        locations: [FloatLocation] = [],
        checkpoints: [Checkpoint] = [],
        hazardSections: [HazardSection] = []
    ) -> Self {
        .init(
            festival: festival,
            districts: districts,
            periods: periods,
            locations: locations,
            checkpoints: checkpoints,
            hazardSections: hazardSections
        )
    }
}

extension LaunchDistrictPack {
    static func mock(
        performances: [Performance] = [],
        routes: [Route] = [],
        points: [Point] = [],
        passages: [RoutePassage] = [],
        currentRouteId: Route.ID? = nil
    ) -> Self {
        .init(
            performances: performances,
            routes: routes,
            points: points,
            passages: passages,
            currentRouteId: currentRouteId
        )
    }
}
