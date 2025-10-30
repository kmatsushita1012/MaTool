//
//  SimpleTime.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation

struct SimpleTime: Codable{
    let hour: Int
    let minute: Int
}

extension SimpleTime: Equatable{}

extension SimpleTime: Comparable {
    static func < (lhs: SimpleTime, rhs: SimpleTime) -> Bool {
        if(lhs.hour != rhs.hour){
           return lhs.hour < rhs.hour
       }else{
           return lhs.minute < rhs.minute
       }
    }
}

extension SimpleTime: Hashable{}

extension SimpleTime {
    var text: String {
        return String(format: "%02d:%02d", hour, minute)
    }
}

extension SimpleTime {
    static let sample = Self(hour: 9 ,minute: 0)
}

extension SimpleTime {
    var toDate: Date {
        var calendar = Calendar.current
        calendar.timeZone = .current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? now
    }
    
    static func fromDate(_ date: Date) -> SimpleTime {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return SimpleTime(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }
}
