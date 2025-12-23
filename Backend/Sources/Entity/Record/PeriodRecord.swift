//
//  PeriodRecord.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/20.
//

import Shared

struct PeriodRecord: Entity {
    let id: String
    let festivalId: String
    let year: Int
    let item: Period
    
    init(_ item: Period) {
        self.id = item.id
        self.festivalId = item.festivalId
        self.year = item.date.year
        self.item = item
    }
}
