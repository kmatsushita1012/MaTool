import Foundation
import Shared

struct FestivalState: Equatable, Sendable {
    let year: Int
    var festival: Festival
    var districts: [District]
    var periods: [Period]
    var checkpoints: [Checkpoint]
    var hazardSections: [HazardSection]
    var floatLocations: [FloatLocation]

    init(_ pack: LaunchFestivalPack, year: Int) {
        self.year = year
        festival = pack.festival
        districts = pack.districts
        periods = pack.periods.filter { $0.date.year == year }
        checkpoints = pack.checkpoints
        hazardSections = pack.hazardSections

        var locationsByDistrict: [District.ID: FloatLocation] = [:]
        for location in pack.locations {
            if let existing = locationsByDistrict[location.districtId],
               existing.timestamp >= location.timestamp {
                continue
            }
            locationsByDistrict[location.districtId] = location
        }
        floatLocations = pack.districts.compactMap { locationsByDistrict[$0.id] }
    }
}

struct RouteState: Equatable, Sendable {
    var route: Route
    var points: [Point]
    var passages: [RoutePassage]

    init(route: Route, points: [Point], passages: [RoutePassage]) {
        self.route = route
        self.points = points.filter { $0.routeId == route.id }
        self.passages = passages.filter { $0.routeId == route.id }
    }

    init(_ pack: RoutePack) {
        self.init(route: pack.route, points: pack.points, passages: pack.passages)
    }
}

struct DistrictState: Equatable, Sendable {
    let districtId: District.ID
    let requestId: UUID
    var performances: [Performance]
    var routes: [Route]

    init(
        districtId: District.ID,
        requestId: UUID = UUID(),
        pack: LaunchDistrictPack,
        currentPeriodIds: Set<Period.ID>
    ) {
        self.districtId = districtId
        self.requestId = requestId
        performances = pack.performances
        routes = pack.routes.filter { currentPeriodIds.contains($0.periodId) }
    }
}

struct AppState: Equatable, Sendable {
    let sessionId: UUID
    var festivalState: FestivalState
    var districtState: DistrictState?
    var routeState: RouteState?
    var districtLoadRequestId: UUID
    var routeLoadRequestId: UUID

    init(
        festivalState: FestivalState,
        districtState: DistrictState? = nil,
        routeState: RouteState? = nil,
        sessionId: UUID = UUID(),
        districtLoadRequestId: UUID = UUID(),
        routeLoadRequestId: UUID = UUID()
    ) {
        self.sessionId = sessionId
        self.festivalState = festivalState
        self.districtState = districtState
        self.routeState = routeState
        self.districtLoadRequestId = districtLoadRequestId
        self.routeLoadRequestId = routeLoadRequestId
    }
}
