//
//  LocalRepository.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation

struct LocalClient{
    var set: (_ key: String, _ value: String) -> Void
    var string:(_ key: String)->String?
}
