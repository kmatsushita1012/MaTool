//
//  SimpleTime.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation
import Shared

extension SimpleTime {
    var text: String {
        return String(format: "%02d:%02d", hour, minute)
    }
}

