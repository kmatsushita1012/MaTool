//
//  Infomation.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation

class Region: Codable,Equatable{
    let id: UUID
    let name: String
    let description: String?
    let imagePath:String?
    
    init(id: UUID, name: String, description: String?=nil, imagePath: String?=nil) {
        self.id = id
        self.name = name
        self.description = description
        self.imagePath = imagePath
    }
    
    static func == (lhs: Region, rhs: Region) -> Bool {
        return lhs.id == rhs.id
    }
}

class District: Codable,Equatable{
    let id: UUID
    let name: String
    let description: String?
    let imagePath:String?
    
    init(id: UUID, name: String, description: String?=nil, imagePath: String?=nil) {
        self.id = id
        self.name = name
        self.description = description
        self.imagePath = imagePath
    }
    
    static func == (lhs: District, rhs: District) -> Bool {
        return lhs.id == rhs.id
    }
}
