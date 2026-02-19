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
                .where{ $0.festivalId == district?.festivalId && $0.date.inYear(year) }
                .leftJoin(Route.all){ $0.id.eq($1.periodId).and($1.districtId.eq(district?.id ?? "") )}
                .select{
                    Element.Columns(period: $0, route: $1)
                }
        )
    }
    
    init(festivalId: Festival.ID, year: Int) {
        self.init(
            Period
                .where{ $0.festivalId == festivalId && $0.date.inYear(year) }
                .leftJoin(Route.all ){ $0.id.eq($1.periodId)}
                .select{
                    Element.Columns(period: $0, route: $1)
                }
        )
    }
    
    init(districtId: District.ID, latest: Bool = false, now: SimpleDate = .now){
        let district = FetchOne(District.find(districtId)).wrappedValue
        if latest {
            let maxYear: Int = FetchAll<Period>(Period.where{ $0.festivalId == district?.festivalId }).wrappedValue.map(\.date.year).max() ?? now.year
            self.init(districtId: districtId, year: maxYear)
        } else {
            self.init(
                Period
                    .where{ $0.festivalId == district?.festivalId  }
                    .leftJoin(Route.where{ $0.districtId == district?.id } ){ $0.id.eq($1.periodId)}
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
        period.shortText
    }
    
    static func < (lhs: RouteEntry, rhs: RouteEntry) -> Bool {
        lhs.period < rhs.period
    }
}

extension FetchAll where Element == RouteEntry {
    init (districtId: District.ID, year: Int) {
        let district = FetchOne(District.find(districtId)).wrappedValue
        self.init(
            Period
                .where{ $0.festivalId == district?.festivalId && $0.date.inYear(year) }
                .join(Route.where{ $0.districtId == district?.id } ){ $0.id.eq($1.periodId)}
                .select{
                    Element.Columns(period: $0, route: $1)
                }
        )
    }
    
    init(festivalId: Festival.ID, year: Int) {
        self.init(
            Period
                .where{ $0.festivalId == festivalId && $0.date.inYear(year) }
                .join(Route.all ){ $0.id.eq($1.periodId)}
                .select{
                    Element.Columns(period: $0, route: $1)
                }
        )
    }
    
    init(districtId: District.ID, latest: Bool = false, now: SimpleDate = .now){
        let district = FetchOne(District.find(districtId)).wrappedValue
        if latest {
            let maxYear: Int = FetchAll<Period>(Period.where{ $0.festivalId == district?.festivalId }).wrappedValue.map(\.date.year).max() ?? now.year
            self.init(districtId: districtId, year: maxYear)
        } else {
            self.init(
                Period
                    .where{ $0.festivalId == district?.festivalId  }
                    .join(Route.where{ $0.districtId == district?.id } ){ $0.id.eq($1.periodId)}
                    .select{
                        Element.Columns(period: $0, route: $1)
                    }
            )
        }
    }
}
