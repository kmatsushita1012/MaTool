//
//  Auth.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

import Foundation

public enum UserRole: Entity {
    case headquarter(String)
    case district(String)
    case guest
}
