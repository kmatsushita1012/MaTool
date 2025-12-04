//
//  DateTime.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

import Foundation

private let japanTimeZone: TimeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current

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
    
    public var isValid: Bool {
        var cal = Calendar.current
        cal.timeZone = japanTimeZone
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return cal.date(from: comps) != nil
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
    
    public var isValid: Bool {
        (0...23).contains(hour) && (0...59).contains(minute)
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

// MARK: - Extension
public extension SimpleDate {
    var toDate: Date {
        var calendar = Calendar.current
        calendar.timeZone = japanTimeZone
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? Date()
    }
    
    static func fromDate(_ date: Date) -> SimpleDate {
        var calendar = Calendar.current
        calendar.timeZone = japanTimeZone
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return SimpleDate(year: comps.year ?? 1970, month: comps.month ?? 1, day: comps.day ?? 1)
    }
    
    static var today: SimpleDate {
        return fromDate(Date())
    }
    
    /// 曜日 (1=日曜, 2=月曜 ... 7=土曜)
    var weekday: Int? {
        var cal = Calendar.current
        cal.timeZone = japanTimeZone
        return cal.component(.weekday, from: toDate)
    }
}

public extension SimpleTime {
    var toDate: Date {
        var calendar = Calendar.current
        calendar.timeZone = japanTimeZone
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? now
    }
    
    static func fromDate(_ date: Date) -> SimpleTime {
        var calendar = Calendar.current
        calendar.timeZone = japanTimeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return SimpleTime(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }
}

public extension Date {
    var stamp: String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = japanTimeZone
        dateFormatter.locale = Locale(identifier: "ja_JP_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return dateFormatter.string(from: Date())
    }
    
    static func theDayAt(date: Date, hour: Int, minute: Int, second: Int) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = japanTimeZone
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
        var calendar = Calendar.current
        calendar.timeZone = japanTimeZone
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)

        var merged = DateComponents()
        merged.year = dateComponents.year
        merged.month = dateComponents.month
        merged.day = dateComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        merged.second = timeComponents.second

        return calendar.date(from: merged) ?? Date()
    }
    
    static func combine(date: SimpleDate, time: SimpleTime) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = japanTimeZone

        var merged = DateComponents()
        merged.year = date.year
        merged.month = date.month
        merged.day = date.day
        merged.hour = time.hour
        merged.minute = time.minute
        merged.second = 0

        return calendar.date(from: merged) ?? Date()
    }
}

