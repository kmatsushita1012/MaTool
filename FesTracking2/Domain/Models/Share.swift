//
//  Share.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation

class Coordinate: Codable{
    let latitude: Double
    let longitude: Double
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
    
class SimpleDate: Codable{
    let year: Int
    let month: Int
    let day: Int
    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}

class Time: Codable{
    let hour: Int
    let minute: Int
    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
}
