//
//  Location.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/18.
//

import CoreLocation
import Combine
import ComposableArchitecture

final class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
    var value: AsyncValue<CLLocation> = .loading

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            value = .success(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        value = .failure(error)
    }
}


extension LocationClient {
    static func live() -> LocationClient {
        let manager = CLLocationManager()
        let delegate = LocationManagerDelegate()
        manager.delegate = delegate
        manager.requestWhenInUseAuthorization()
        manager.requestAlwaysAuthorization()
        manager.allowsBackgroundLocationUpdates = true
        var isTracking = false
        
        return LocationClient(
            startTracking: {
                manager.startUpdatingLocation()
                isTracking = true
            },
            getLocation: {
                if CLLocationManager.authorizationStatus() == .denied {
                    return .failure(LocationError.authorizationDenied)
                }
                if !CLLocationManager.locationServicesEnabled() {
                    return .failure(LocationError.servicesDisabled)
                }
                if let location = manager.location {
                    return .success(location)
                } else {
                    return .loading
                }
            },
            isTracking: {
                return isTracking
            },
            stopTracking: {
                manager.stopUpdatingLocation()
                isTracking = false
            }
        )
    }
}

struct AsyncTimerSequence: AsyncSequence {
    typealias Element = Void

    let interval: TimeInterval

    struct AsyncIterator: AsyncIteratorProtocol {
        let interval: TimeInterval

        mutating func next() async -> Void? {
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            return ()
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        .init(interval: interval)
    }
}

