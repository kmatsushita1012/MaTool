//
//  Others.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/24.
//

import Shared

enum LaunchState: Entity {
    case district(UserRole, Route.ID?)
    case festival(UserRole)
    case onboarding
    case loading
    case error(String)
}
