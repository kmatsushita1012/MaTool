//
//  DateAndTime.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/08.
//

import Foundation


struct DateTime: Codable{
    let date: SimpleDate
    let time: SimpleTime
}

extension DateTime: Equatable{
    static func == (lhs: DateTime, rhs: DateTime) -> Bool {
        return  lhs.date == rhs.date && lhs.time == rhs.time
    }
}

extension DateTime: Comparable{
    static func < (lhs: DateTime, rhs: DateTime) -> Bool {
        if(lhs.date == rhs.date){
            return lhs.time < rhs.time
        }else{
            return lhs.date < rhs.date
        }
    }
}

extension DateTime {
    static var now: DateTime {
        let currentDate = Date()
        let calendar = Calendar.current
        let simpleDate = SimpleDate(
            year: calendar.component(.year, from: currentDate),
            month: calendar.component(.month, from: currentDate),
            day: calendar.component(.day, from: currentDate)
        )
        let simpleTime = SimpleTime(
            hour: calendar.component(.hour, from: currentDate),
            minute: calendar.component(.minute, from: currentDate)
        )
        
        return DateTime(date: simpleDate, time: simpleTime)
    }
    
    func text(year: Bool = true, month: Bool = true, day: Bool = true) -> String {
        return "\(date.text(year: year, month:  month, day:  day)) \(time.text)"
    }
}

extension DateTime {
    static let sample = Self(date: SimpleDate.sample, time: SimpleTime.sample)
}
