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
    func text(format: String) -> String {
        var result = ""
        
        var i = format.startIndex
        while i < format.endIndex {
            let char = format[i]
            
            switch char {
            case "D":
                result += districtName
            case "T":
                result += title
            case "y":
                result += String(date.year)
            case "m":
                result += String(format: "%02d", date.month)
            case "d":
                result += String(format: "%02d", date.day)
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
        districtId: "Johoku",
        districtName: "城北町",
        date: SimpleDate.sample,
        title: "午後",
    )
}
