//
//  SimpleDate.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation

struct SimpleDate: Codable{
    let year: Int
    let month: Int
    let day: Int
}

extension SimpleDate: Equatable{
    static func == (lhs: SimpleDate, rhs: SimpleDate) -> Bool {
        return  lhs.year == rhs.year && lhs.month == rhs.month && lhs.day == rhs.day
    }
}

extension SimpleDate {
    static let sample = Self(year: 2025, month: 10, day: 12)
}

extension SimpleDate {
    func toDate() -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        return Calendar.current.date(from: components) ?? Date()
    }
    
    static func fromDate(_ date: Date) -> SimpleDate {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return SimpleDate(year: year, month: month, day: day)
    }
    
    static var today: SimpleDate {
        return fromDate(Date())
    }
}
