//
//  Others.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/24.
//

import Shared
import MapKit

public extension Coordinate {
    func toCL() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
    static func fromCL(_ coordinate: CLLocationCoordinate2D)->Coordinate{
        return Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

import Shared

enum LaunchState: Entity {
    case district(UserRole ,Route.ID?) // ホーム画面&町登録あり
    case festival(UserRole) // ホーム画面&町登録なし
    case onboarding
    case loading
    case error(String)
}
