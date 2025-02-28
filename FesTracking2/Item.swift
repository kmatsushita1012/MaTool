//
//  Item.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/02/28.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
