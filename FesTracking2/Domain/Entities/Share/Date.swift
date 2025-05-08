//
//  Date.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/21.
//

import Foundation

extension Date {
    static let sample: Date = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
            return formatter.date(from: "2025/10/12 12:00:00")!
        }()
    
    func text (year:Bool = true) -> String {
        let formatter = DateFormatter()
        // 年を含めるかどうかでフォーマットを切り替える
        formatter.dateFormat = year ? "yyyy/MM/dd HH:mm:ss" : "MM/dd HH:mm:ss"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: self)
    }
    
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
