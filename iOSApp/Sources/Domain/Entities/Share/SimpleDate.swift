//
//  SimpleDate.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation
import Shared

extension SimpleDate {
    func text(format: String = "y/m/d") -> String {
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
    /// 日本語の曜日 ("日","月","火","水","木","金","土")
    var weekdaySymbol: String? {
        guard let weekday else { return nil }
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]
        return symbols[weekday - 1]
    }
}
