//
//  LocationClient.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/18.
//

import Combine
import ComposableArchitecture
import CoreLocation

struct LocationClient {
    var startTracking: () -> Void
    var getLocation:() -> AsyncValue<CLLocation>
    var isTracking:() ->Bool
    var stopTracking: () -> Void
}



extension DependencyValues {
    var locationClient: LocationClient {
        get { self[LocationClientKey.self] }
        set { self[LocationClientKey.self] = newValue }
    }

    private enum LocationClientKey: DependencyKey {
        static var liveValue: LocationClient {
            .live()
        }
    }
}
enum LocationError: Error {
    case authorizationDenied
    case servicesDisabled
}
