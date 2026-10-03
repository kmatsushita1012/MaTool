//
//  RouteEntry.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/17.
//

import Shared
import SQLiteData


@Selection struct RouteSlot: Entity{
    let period: Period
    let route: Route?
}

extension RouteSlot: Identifiable {
    var id: String {
        period.id
    }
    
    var text: String {
        period.shortText
    }
}

extension FetchAll where Element == RouteSlot {
    init(districtId: District.ID, year: Int) {
        let district = FetchOne(District.find(districtId)).wrappedValue
        self.init(
            Period
                .where{ $0.festivalId.eq(district?.festivalId) && $0.date.inYear(year) }
                .leftJoin(Route.all){ $0.id.eq($1.periodId).and($1.districtId.eq(district?.id) )}
                .select{
                    Element.Columns(period: $0, route: $1)
                }
        )
    }
    
    init(festivalId: Festival.ID, year: Int) {
        self.init(
            Period
                .where{ $0.festivalId.eq(festivalId) && $0.date.inYear(year) }
                .leftJoin(Route.all ){ $0.id.eq($1.periodId)}
                .select{
                    Element.Columns(period: $0, route: $1)
                }
        )
    }
    
    init(districtId: District.ID, latest: Bool = false, now: SimpleDate = .now){
        let district = FetchOne(District.find(districtId)).wrappedValue
        if latest {
            let maxYear: Int = FetchAll<Period>(Period.where{ $0.festivalId.eq(district?.festivalId) }).wrappedValue.map(\.date.year).max() ?? now.year
            self.init(districtId: districtId, year: maxYear)
        } else {
            self.init(
                Period
                    .where{ $0.festivalId.eq(district?.festivalId)  }
                    .leftJoin(Route.where{ $0.districtId.eq(district?.id) } ){ $0.id.eq($1.periodId)}
                    .select{
                        Element.Columns(period: $0, route: $1)
                    }
                )
        }
    }
}


@Selection struct RouteEntry: Equatable{
    let period: Period
    let route: Route
}

extension RouteEntry: Identifiable, Comparable {
    var id: String {
        route.id
    }
    
    var text: String {
        let dateText = period.date.text(format: "m/d")
        let weekdayText = period.date.weekdaySymbol ?? ""
        return "\(dateText)（\(weekdayText)）\(period.title)"
    }
    
    static func < (lhs: RouteEntry, rhs: RouteEntry) -> Bool {
        lhs.period < rhs.period
    }
}

struct LatestRouteEntryResolution {
    let periods: [Period]
    let year: Int
}

enum LatestRouteEntryResolver {
    static func resolve(
        periods: [Period],
        routes: [RouteEntry],
        nowYear: Int
    ) -> LatestRouteEntryResolution {
        let nextYearPeriods = periods.filter { $0.date.year == nowYear + 1 }
        let currentYearPeriods = periods.filter { $0.date.year == nowYear }
        let candidatePeriods: [Period]

        if nextYearPeriods.isEmpty {
            candidatePeriods = currentYearPeriods + periods.filter { $0.date.year == nowYear - 1 }
        } else {
            candidatePeriods = nextYearPeriods + currentYearPeriods
        }

        let routePeriodIDs = Set(routes.map(\.period.id))
        let candidateYears = Set(candidatePeriods.map(\.date.year)).sorted(by: >)
        let yearWithRoute = candidateYears.first { year in
            candidatePeriods.contains { $0.date.year == year && routePeriodIDs.contains($0.id) }
        }

        return LatestRouteEntryResolution(
            periods: candidatePeriods,
            year: yearWithRoute ?? candidateYears.first ?? nowYear
        )
    }
}

extension FetchAll where Element == RouteEntry {
    init (districtId: District.ID, year: Int) {
        let district = FetchOne(District.find(districtId)).wrappedValue
        self.init(
            Period
                .where{ $0.festivalId.eq(district?.festivalId) && $0.date.inYear(year) }
                .join(Route.where{ $0.districtId.eq(district?.id) } ){ $0.id.eq($1.periodId)}
                .select{
                    Element.Columns(period: $0, route: $1)
                }
        )
    }
    
    init(festivalId: Festival.ID, year: Int) {
        self.init(
            Period
                .where{ $0.festivalId.eq(festivalId) && $0.date.inYear(year) }
                .join(Route.all ){ $0.id.eq($1.periodId)}
                .select{
                    Element.Columns(period: $0, route: $1)
                }
        )
    }
    
    init(districtId: District.ID, latest: Bool = false, now: SimpleDate = .now){
        let district = FetchOne(District.find(districtId)).wrappedValue
        if latest {
            let periods = FetchAll<Period>(
                Period.where { $0.festivalId.eq(district?.festivalId) }
            ).wrappedValue
            let routes = FetchAll<RouteEntry>(districtId: districtId).wrappedValue
            let resolution = LatestRouteEntryResolver.resolve(
                periods: periods,
                routes: routes,
                nowYear: now.year
            )
            self.init(districtId: districtId, year: resolution.year)
        } else {
            self.init(
                Period
                    .where{ $0.festivalId.eq(district?.festivalId)  }
                    .join(Route.where{ $0.districtId.eq(district?.id) } ){ $0.id.eq($1.periodId)}
                    .select{
                        Element.Columns(period: $0, route: $1)
                    }
            )
        }
    }
}
