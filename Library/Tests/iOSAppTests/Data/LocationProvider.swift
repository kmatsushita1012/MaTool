//
//  LocationProvider.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/18.
//

import Dependencies
import CoreLocation
import Combine

// MARK: - Dependencies
enum LocationProviderKey: DependencyKey{
    static let liveValue: LocationProviderProtocol = LocationProvider()
}

extension DependencyValues {
    var locationProvider: LocationProviderProtocol {
        get { self[LocationProviderKey.self] }
        set { self[LocationProviderKey.self] = newValue }
    }
}

// MARK: - LocationProviderProtocol
protocol LocationProviderProtocol: Sendable {
    func requestPermission() async -> Void
    func startTracking(backgroundUpdatesAllowed: Bool, onUpdate: ((AsyncValue<CLLocation>) async -> Void)?) async -> Void
    func stopTracking() async -> Void
    func getLocation() async -> AsyncValue<CLLocation>
    func isPermissionAllowed() async -> Bool
    var isTracking: Bool { get async }
}

// MARK: - LocationProvider
actor LocationProvider: NSObject, LocationProviderProtocol {
    private(set) var manager: CLLocationManager? = nil
    private(set) var isTracking = false
    private(set) var value: AsyncValue<CLLocation> = .loading
    private(set) var onUpdate: ((AsyncValue<CLLocation>) async ->Void)? = nil

    override init() {
        super.init()
        Task{
            await setupLocationManagerIfNeeded()
        }
    }
    
    private func setupLocationManagerIfNeeded() async {
        let manager = await MainActor.run {
            let manager = CLLocationManager()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.pausesLocationUpdatesAutomatically = false
            return manager
        }
        if self.manager == nil {
            self.manager = manager
        }
        
    }

    func requestPermission() async {
        await setupLocationManagerIfNeeded()
        manager?.requestWhenInUseAuthorization()
        manager?.requestAlwaysAuthorization()
    }

    func startTracking(backgroundUpdatesAllowed: Bool, onUpdate: ((AsyncValue<CLLocation>) async -> Void)?) {
        if backgroundUpdatesAllowed {
            manager?.allowsBackgroundLocationUpdates = true
        }
        if self.onUpdate == nil, onUpdate != nil{
            self.onUpdate = onUpdate
        }
        manager?.startUpdatingLocation()
        isTracking = true
        
        if let cached = manager?.location {
            value = .success(cached)
        }
    }

    func stopTracking() {
        manager?.stopUpdatingLocation()
        manager?.allowsBackgroundLocationUpdates = false
        isTracking = false
        onUpdate = nil
    }

    func getLocation() -> AsyncValue<CLLocation> {
        if manager?.authorizationStatus == .denied {
            return .failure(LocationError.authorizationDenied)
        }
        if !CLLocationManager.locationServicesEnabled() {
            return .failure(LocationError.servicesDisabled)
        }
        
        return value
    }

    func isPermissionAllowed() -> Bool {
        return manager?.authorizationStatus != .denied
    }

    private func updateValue(_ newValue: AsyncValue<CLLocation>) {
        self.value = newValue
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task{
            await  updateValue(.success(location))
            await onUpdate?(.success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task{ await updateValue(.failure(error)) }
    }
}

// MARK: - LocationProviderProtocol+
extension LocationProviderProtocol {
    func startTracking(backgroundUpdatesAllowed: Bool, onUpdate: ((AsyncValue<CLLocation>) async -> Void)? = nil) async -> Void {
        await startTracking(backgroundUpdatesAllowed: backgroundUpdatesAllowed, onUpdate: onUpdate)
    }
}


enum LocationError: Error {
    case authorizationDenied
    case servicesDisabled
}
