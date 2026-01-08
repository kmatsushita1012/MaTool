//
//  RouteItem.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation
import Shared


extension RoutesResponse.Item{
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
            case "T":
                result += period.title
            case "y":
                result += String(period.date.year)
            case "m":
                if nextChar == "2" {
                    result += String(format: "%02d", period.date.month)
                    i = format.index(after: nextIndex) // "m2" 消費
                    continue
                } else {
                    result += String(period.date.month)
                }
            case "d":
                if nextChar == "2" {
                    result += String(format: "%02d", period.date.day)
                    i = format.index(after: nextIndex) // "d2" 消費
                    continue
                } else {
                    result += String(period.date.day)
                }
            case "w":
                result += period.date.weekdaySymbol ?? ""
            default:
                result += String(char)
            }

            i = format.index(after: i)
        }
        return result
    }
}
