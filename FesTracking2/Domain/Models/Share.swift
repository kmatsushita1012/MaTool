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
}
    
class Date: Codable{
    let year: Int
    let month: Int
    let day: Int
}

class Time: Codable{
    let hour: Int
    let minute: Int
}
