//
//  Others.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/24.
//

struct InfoItem: Equatable, Hashable{
    let title: String
    let description: String?
}

struct Information: Codable, Equatable, Hashable, Identifiable{
    let id: String
    var name: String = ""
    @NullEncodable var description: String? = nil
}

struct Empty: Equatable {}
