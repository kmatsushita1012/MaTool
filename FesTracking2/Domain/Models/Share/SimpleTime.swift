//
//  SimpleTime.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//

struct SimpleTime: Codable{
    let hour: Int
    let minute: Int
    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
}

extension SimpleTime: Equatable{
    
}

extension SimpleTime {
    static let sample = Self(hour: 9 ,minute: 0)
}
