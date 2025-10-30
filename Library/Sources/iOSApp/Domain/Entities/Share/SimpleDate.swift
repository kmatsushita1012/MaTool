//
//  SimpleDate.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation

struct SimpleDate: Codable, Equatable, Hashable{
    let year: Int
    let month: Int
    let day: Int
}


extension SimpleDate: Comparable {
    static func < (lhs: SimpleDate, rhs: SimpleDate) -> Bool {
        if(lhs.year != rhs.year){
            return lhs.year < rhs.year
        }else if(lhs.month != rhs.month){
            return lhs.month < rhs.month
        }else{
            return lhs.day < rhs.day
        }
    }
}


extension SimpleDate {
    func text(format: String) -> String {
        var result = ""
        var i = format.startIndex

        while i < format.endIndex {
            let char = format[i]

            // 次の2文字目を読み取れるなら見る
            let nextIndex = format.index(after: i)
            let hasNext = nextIndex < format.endIndex
            let nextChar = hasNext ? format[nextIndex] : nil

            switch char {
            case "y":
                result += String(year)
            case "m":
                if nextChar == "2" {
                    result += String(format: "%02d", month)
                    i = format.index(after: nextIndex)
                    continue
                } else {
                    result += String(month)
                }
            case "d":
                if nextChar == "2" {
                    result += String(format: "%02d", day)
                    i = format.index(after: nextIndex)
                    continue
                } else {
                    result += String(day)
                }
            default:
                result += String(char)
            }

            i = format.index(after: i)
        }

        return result
    }
}

extension SimpleDate {
    static let sample = Self(year: 2025, month: 10, day: 12)
}

extension SimpleDate {
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
}

extension SimpleDate {
    /// Foundation.Date に変換
    var date: Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)
    }
    
    /// 曜日 (1=日曜, 2=月曜 ... 7=土曜)
    var weekday: Int? {
        guard let date else { return nil }
        return Calendar.current.component(.weekday, from: date)
    }
    
    /// 日本語の曜日 ("日","月","火","水","木","金","土")
    var weekdaySymbol: String? {
        guard let weekday else { return nil }
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]
        return symbols[weekday - 1]
    }
}
