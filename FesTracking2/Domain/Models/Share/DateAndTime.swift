//
//  DateAndTime.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/08.
//


struct DateTime: Codable{
    let date: SimpleDate
    let time: SimpleTime
}

extension DateTime: Equatable{
    static func == (lhs: DateTime, rhs: DateTime) -> Bool {
        return  lhs.date == rhs.date && lhs.time == rhs.time
    }
}

extension DateTime {
    static let sample = Self(date: SimpleDate.sample, time: SimpleTime.sample)
}
