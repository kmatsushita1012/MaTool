//
//  RouteSummary.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation

struct RouteSummary: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let districtId: String
    let districtName: String
    let date:SimpleDate
    let title: String
    let start: SimpleTime
}

extension RouteSummary: Comparable {
    static func < (lhs: RouteSummary, rhs: RouteSummary) -> Bool {
        if(lhs.date != rhs.date){
            return lhs.date < rhs.date
        }else{
            return lhs.start < rhs.start
        }
    }
}


extension RouteSummary{
    init(from route: RouteInfo) {
        self.id = route.id
        self.districtId = route.districtId
        self.districtName = route.districtName
        self.date = route.date
        self.title = route.title
        self.start = route.start
    }
    
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
            case "D":
                result += districtName
            case "T":
                result += title
            case "y":
                result += String(date.year)
            case "m":
                if nextChar == "2" {
                    result += String(format: "%02d", date.month)
                    i = format.index(after: nextIndex) // "m2" 消費
                    continue
                } else {
                    result += String(date.month)
                }
            case "d":
                if nextChar == "2" {
                    result += String(format: "%02d", date.day)
                    i = format.index(after: nextIndex) // "d2" 消費
                    continue
                } else {
                    result += String(date.day)
                }
            case "w":
                result += date.weekdaySymbol ?? ""
            default:
                result += String(char)
            }

            i = format.index(after: i)
        }
        return result
    }
}

extension RouteSummary{
    static let sample = Self(
        id: UUID().uuidString,
        districtId: "Johoku",
        districtName: "城北町",
        date: SimpleDate.sample,
        title: "午後",
        start: SimpleTime(hour: 9, minute: 0)
    )
}
