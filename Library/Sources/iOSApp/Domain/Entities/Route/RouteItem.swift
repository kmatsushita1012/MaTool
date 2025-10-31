//
//  RouteItem.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation
import Shared


extension RouteItem{
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
