//
//  Share.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//
import Foundation

struct Route: Codable{
    let id: UUID
    let region: String
    let district: String
    let points: [Point]
    let segments: [Segment]
    let date:Date
    let title: String
    let description: String
}

struct Point: Codable{
    let coordinate: Coordinate
    let title: String
    let description: String
    let time: Time
}

struct Segment: Codable{
    let points: [Coordinate]
}
