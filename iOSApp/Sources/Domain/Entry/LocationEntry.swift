//
//  LocationEntry.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/18.
//

import Shared
import SQLiteData

@Selection struct FloatEntry: Entity {
    let floatLocation: FloatLocation
    let district: District
}

extension FloatEntry: Identifiable {
    var id: FloatLocation.ID { floatLocation.id }
}

extension FetchAll where Element == FloatEntry {
    init(festivalId: Festival.ID){
        self.init(
            District
                .where{ $0.festivalId.eq(festivalId) }
                .join(FloatLocation.all) { $0.id.eq($1.districtId) }
                .select{
                    FloatEntry.Columns(floatLocation: $1, district: $0)
                }
        )
    }
}

extension FetchOne where Value == FloatEntry? {
    init(districtId: District.ID){
        self.init(
            FloatLocation
                .where{ $0.districtId.eq(districtId) }
                .join(District.all) { $0.districtId.eq($1.id) }
                .select{
                    FloatEntry.Columns(floatLocation: $0, district: $1)
                }
        )
    }
}
