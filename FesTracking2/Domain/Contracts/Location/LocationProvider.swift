//
//  LocationProvider.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/18.
//

import Combine
import ComposableArchitecture
import CoreLocation

struct LocationProvider {
    var startTracking: () -> Void
    var getLocation:() -> AsyncValue<CLLocation>
    var isTracking:() ->Bool
    var stopTracking: () -> Void
}



extension DependencyValues {
    var locationClient: LocationProvider {
        get { self[LocationProviderKey.self] }
        set { self[LocationProviderKey.self] = newValue }
    }

    private enum LocationProviderKey: DependencyKey {
        static var liveValue: LocationProvider {
            .live()
        }
    }
}
enum LocationError: Error {
    case authorizationDenied
    case servicesDisabled
}
