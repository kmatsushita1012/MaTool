//
//  Auth.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

import Foundation

public enum UserRole: Entity {
    case region(String)
    case district(String)
    case guest
}
