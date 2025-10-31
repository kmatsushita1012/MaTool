//
//  DateTime.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

import Foundation

// MARK: - SimpleDate
public struct SimpleDate: Entity {
    public let year: Int
    public let month: Int
    public let day: Int
    
    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}

extension SimpleDate: Comparable {
    public static func < (lhs: SimpleDate, rhs: SimpleDate) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }else if lhs.month != rhs.month {
            return lhs.month < rhs.month
        }else{
            return lhs.day < rhs.day
        }
    }
}

// MARK: - SimpleTime
public struct SimpleTime: Entity {
    public let hour: Int
    public let minute: Int
    
    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
    
}


extension SimpleTime: Comparable {
    public static func < (lhs: SimpleTime, rhs: SimpleTime) -> Bool {
        if(lhs.hour != rhs.hour){
           return lhs.hour < rhs.hour
       }else{
           return lhs.minute < rhs.minute
       }
    }
}

// MARK: - Span
public struct Span: Entity {
    public let id: String
    public let start: Date
    public let end: Date
    
    public init(id: String, start: Date, end: Date) {
        self.id = id
        self.start = start
        self.end = end
    }
}

extension Span: Identifiable { }

extension Span: Comparable {
    public static func < (lhs: Span, rhs: Span) -> Bool {
        return lhs.start < rhs.start
    }
}


// MARK: - Extension
public extension SimpleDate {
    var toDate: Date {
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
    
    /// 曜日 (1=日曜, 2=月曜 ... 7=土曜)
    var weekday: Int? {
        return Calendar.current.component(.weekday, from: toDate)
    }
}

public extension SimpleTime {
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

public extension Date {
    var stamp: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return dateFormatter.string(from: Date())
    }
    
    static func theDayAt(date: Date, hour: Int, minute: Int, second: Int) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        // 日付部分を生成
        guard let dateWithoutTime = calendar.date(from: components) else {
            // 失敗した場合は現在時刻で返す
            return Date()
        }
        
        // 時刻を設定
        guard let finalDate = calendar.date(bySettingHour: hour, minute: minute, second: second, of: dateWithoutTime) else {
            // 失敗した場合は現在時刻で返す
            return Date()
        }
        
        return finalDate
    }
    
    static func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)

        var merged = DateComponents()
        merged.year = dateComponents.year
        merged.month = dateComponents.month
        merged.day = dateComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        merged.second = timeComponents.second

        return calendar.date(from: merged)!
    }
}

