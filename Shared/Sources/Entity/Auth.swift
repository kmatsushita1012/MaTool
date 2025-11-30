//
//  Auth.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

import Foundation
import CasePaths

@CasePathable
public enum UserRole: Entity {
    case headquarter(String)
    case district(String)
    case guest
}

extension UserRole{
    public var id: String? {
        switch self {
        case .headquarter(let id):
            return id
        case .district(let id):
            return id
        case .guest:
            return nil
        }
    }
}
