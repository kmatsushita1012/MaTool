import Foundation
import Shared

extension SimpleDate {
    func text(format: String = "y/m/d") -> String {
        var result = ""
        var i = format.startIndex

        while i < format.endIndex {
            let char = format[i]
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
                }
                result += String(month)
            case "d":
                if nextChar == "2" {
                    result += String(format: "%02d", day)
                    i = format.index(after: nextIndex)
                    continue
                }
                result += String(day)
            case "w":
                result += weekdaySymbol ?? ""
            default:
                result += String(char)
            }

            i = format.index(after: i)
        }

        return result
    }

    var weekdaySymbol: String? {
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]
        return symbols[weekday - 1]
    }
}

extension SimpleTime {
    var text: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

extension Period {
    var text: String {
        String(
            format: "%d/%d %@ %02d:%02d〜%02d:%02d",
            date.month,
            date.day,
            title,
            start.hour,
            start.minute,
            end.hour,
            end.minute
        )
    }

    var shortText: String {
        String(
            format: "%d/%d %@",
            date.month,
            date.day,
            title
        )
    }

    func text(dateFormat: String = "y/m/d") -> String {
        "\(date.text(format: dateFormat)) \(title)"
    }

    func text(year: Bool = true) -> String {
        if year {
            return "\(date.text(format: "Y/M/D"))  \(start.hour):\(start.minute)〜\(end.hour):\(end.minute)"
        }
        return "\(date.text(format: "M/D"))  \(start.hour):\(start.minute)〜\(end.hour):\(end.minute)"
    }

    var path: String {
        "\(date.year)-\(date.month)-\(date.day)-\(title)"
    }
}
