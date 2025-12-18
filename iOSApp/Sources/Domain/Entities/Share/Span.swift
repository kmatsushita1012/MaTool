//
//  Period.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/08.
//

import Foundation
import Shared

extension Period {
    func text(year: Bool = true) -> String {
        if year {
            return "\(date.text(format: "Y/M/D"))  \(start.hour):\(start.minute)〜\(end.hour):\(end.minute)"
        } else {
            return "\(date.text(format: "M/D"))  \(start.hour):\(start.minute)〜\(end.hour):\(end.minute)"
        }
    }
}


