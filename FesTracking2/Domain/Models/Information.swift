//
//  Infomation.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation

class Region: Codable{
    let id: UUID
    let name: String
    let description: String
    let imagePath:String
}

class District: Codable{
    let id: UUID
    let name: String
    let description: String
    let imagePath:String
}
