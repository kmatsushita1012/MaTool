//
//  Others.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/24.
//

public struct InfoItem: Entity {
    public let title: String
    public let description: String?
}

public struct Pair<Element: Equatable>: Equatable {
    public let first: Element
    public let second: Element
}

public struct Empty: Equatable, Codable {
    public init(){}
}

public struct ImagePath: Entity {
    public let light: String?
    public let dark: String?
    
    public init(light: String?, dark: String?) {
        self.light = light
        self.dark = dark
    }
}
