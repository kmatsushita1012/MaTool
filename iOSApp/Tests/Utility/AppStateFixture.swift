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

    static func edition(year: Int = 2026) -> Edition {
        Edition(id: "edition", festivalId: "festival", year: year)
    }

    static func period(
        id: String = "period",
        day: Int = 3,
        startHour: Int = 9,
        edition: Edition? = nil
    ) -> Period {
        let targetEdition = edition ?? AppStateFixture.edition()
        return Period(
            id: id,
            editionId: targetEdition.id,
            festivalId: targetEdition.festivalId,
            date: SimpleDate(year: targetEdition.year, month: 10, day: day),
            start: SimpleTime(hour: startHour, minute: 0),
            end: SimpleTime(hour: 17, minute: 0)
        )
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
        districts: [District] = [AppStateFixture.district()],
        periods: [Period] = [AppStateFixture.period()],
        routes: [Route] = [],
        performances: [Performance] = [],
        locations: [FloatLocation] = [],
        points: [Point] = [],
        passages: [RoutePassage] = [],
        currentRouteId: String? = nil,
        selectedDistrictId: String? = "district",
        year: Int = 2026,
        hasEdition: Bool = true,
        edition customEdition: Edition? = nil
    ) -> AppState {
        let edition = hasEdition ? (customEdition ?? AppStateFixture.edition(year: year)) : nil
        let festivalPack = LaunchFestivalPack(
            festival: festival(), edition: edition, districts: districts,
            periods: periods, locations: locations,
            checkpoints: [], hazardSections: []
        )
        let districtPack: LaunchDistrictPack? = selectedDistrictId.map { _ in
            LaunchDistrictPack(
                editionId: edition?.id,
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
