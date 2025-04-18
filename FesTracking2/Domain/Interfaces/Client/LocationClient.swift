//
//  LocationClient.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/18.
//

import Combine
import ComposableArchitecture
import CoreLocation

struct LocationClient<Action> {
    var startTracking: () -> Effect<Action>
    var stopTracking: () -> Void
}


extension DependencyValues {
    var locationClient: LocationClient<LocationAdminFeature.Action> {
        get { self[LocationClientKey.self] }
        set { self[LocationClientKey.self] = newValue }
    }

    private enum LocationClientKey: DependencyKey {
        static var liveValue: LocationClient<LocationAdminFeature.Action> {
            .live(action: LocationAdminFeature.Action.updated, interval: 1)
        }
    }
}
