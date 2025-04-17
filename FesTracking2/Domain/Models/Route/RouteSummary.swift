//
//  RouteSummary.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation

struct RouteSummary: Codable{
    let districtId: String
    let date:SimpleDate
    let title: String
    init(districtId: String, date: SimpleDate, title: String) {
        self.districtId = districtId
        self.date = date
        self.title = title
    }
}

extension RouteSummary: Equatable{
    static func == (lhs: RouteSummary, rhs: RouteSummary) -> Bool {
        return lhs.districtId == rhs.districtId && lhs.date == rhs.date && lhs.title == rhs.title
    }
}

extension RouteSummary: Identifiable {
    var id: String {
        return "\(districtId)_\(date.year)-\(date.month)-\(date.day)_\(title)"
    }
}

extension RouteSummary{
    static let sample = Self(districtId: "johoku", date: SimpleDate.sample, title: "午後")
}
