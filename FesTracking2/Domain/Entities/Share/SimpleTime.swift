//
//  SimpleTime.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//

struct SimpleTime: Codable{
    let hour: Int
    let minute: Int
}

extension SimpleTime: Equatable{}

extension SimpleTime: Comparable {
    static func < (lhs: SimpleTime, rhs: SimpleTime) -> Bool {
        if(lhs.hour != rhs.hour){
           return lhs.hour < rhs.hour
       }else{
           return lhs.minute < rhs.minute
       }
    }
}

extension SimpleTime: Hashable{}

extension SimpleTime {
    var text: String {
        return String(format: "%02d:%02d", hour, minute)
    }
}

extension SimpleTime {
    static let sample = Self(hour: 9 ,minute: 0)
}

