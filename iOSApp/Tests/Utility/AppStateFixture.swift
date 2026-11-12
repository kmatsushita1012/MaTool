import Foundation
import Shared
@testable import iOSApp

enum AppStateFixture {
    static func festival() -> Festival {
        Festival(id: "festival", name: "Festival", subname: "Festival",
                 base: Coordinate(latitude: 35, longitude: 139))
    }

    static func district(
        id: String = "district",
        name: String = "District",
        group: String? = nil
    ) -> District {
        District(id: id, name: name, festivalId: "festival", group: group)
    }

    static func period(
        id: String = "period",
        day: Int = 3,
        startHour: Int = 9
    ) -> Period {
        Period(id: id, festivalId: "festival",
               date: SimpleDate(year: 2026, month: 10, day: day),
               start: SimpleTime(hour: startHour, minute: 0),
               end: SimpleTime(hour: 17, minute: 0))
    }

    static func route(
        id: String = "route",
        periodId: String = "period",
        districtId: String = "district",
        description: String? = nil
    ) -> Route {
        Route(id: id, districtId: districtId, periodId: periodId,
              visibility: .admin, description: description)
    }

    static func state(
        districts: [District] = [district()],
        periods: [Period] = [period()],
        routes: [Route] = [],
        performances: [Performance] = [],
        locations: [FloatLocation] = [],
        points: [Point] = [],
        passages: [RoutePassage] = [],
        currentRouteId: String? = nil,
        selectedDistrictId: String? = "district",
        year: Int = 2026
    ) -> AppState {
        let festivalPack = LaunchFestivalPack(
            festival: festival(), year: year, districts: districts,
            periods: periods, locations: locations,
            checkpoints: [], hazardSections: []
        )
        let districtPack: LaunchDistrictPack? = selectedDistrictId.map { _ in
            LaunchDistrictPack(
                performances: performances, routes: routes,
                points: points, passages: passages,
                currentRouteId: currentRouteId
            )
        }
        return AppState(
            festivalPack: festivalPack,
            districtPack: districtPack,
            districtId: selectedDistrictId
        )
    }
}
