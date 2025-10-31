//
//  CurrentResponce.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/21.
//

struct CurrentResponse: Codable, Equatable {
    let districtId: String
    let districtName: String
    let routes: [RouteSummary]?
    let current: Route?
    let location: LocationInfo?
}
