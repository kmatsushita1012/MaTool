//
//  Span.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/08.
//

import Foundation
import Shared

extension Span {
    func text(year: Bool = true) -> String {
        let calendar = Calendar.current
        let startDateOnly = calendar.startOfDay(for: start)
        let endDateOnly = calendar.startOfDay(for: end)
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = year ? "yyyy/M/d" : "M/d"
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ja_JP")
        timeFormatter.dateFormat = "HH:mm"

        if startDateOnly == endDateOnly {
            return "\(dateFormatter.string(from: start))  \(timeFormatter.string(from: start))〜\(timeFormatter.string(from: end))"
        } else {
            return "\(dateFormatter.string(from: start))  \(timeFormatter.string(from: start))〜\(dateFormatter.string(from: end))  \(timeFormatter.string(from: end))"
        }
    }
}


