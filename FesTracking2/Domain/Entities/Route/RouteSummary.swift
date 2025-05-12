//
//  RouteSummary.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation

struct RouteSummary: Codable, Equatable{
    let districtId: String
    let districtName: String
    let date:SimpleDate
    let title: String
}

extension RouteSummary: Identifiable, Hashable {
    var id: String {
        return "\(districtId)_\(date.year)-\(date.month)-\(date.day)_\(title)"
    }
    
}

extension RouteSummary{
    init(from route: PublicRoute) {
        self.districtId = route.districtId
        self.districtName = route.districtName
        self.date = route.date
        self.title = route.title
    }
    var text: String {
        return "\(date.month)/\(date.day) \(title)"
    }
}

extension RouteSummary{
    static let sample = Self(
        districtId: "Johoku",
        districtName: "城北町",
        date: SimpleDate.sample,
        title: "午後",
    )
}
