import iOSShared
//
//  LocationProvider.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/18.
//

import Dependencies
import CoreLocation
import Combine

// MARK: - LocationProvider
public actor LocationProvider: NSObject, LocationProviderProtocol {
    private(set) var manager: CLLocationManager? = nil
    public private(set) var isTracking = false
    private(set) var value: AsyncValue<CLLocation> = .loading
    private(set) var onUpdate: ((AsyncValue<CLLocation>) async ->Void)? = nil

    public override init() {
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

    public func requestPermission() async {
        await setupLocationManagerIfNeeded()
        manager?.requestWhenInUseAuthorization()
        manager?.requestAlwaysAuthorization()
    }

    public func startTracking(backgroundUpdatesAllowed: Bool, onUpdate: ((AsyncValue<CLLocation>) async -> Void)?) {
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

    public func stopTracking() {
        manager?.stopUpdatingLocation()
        manager?.allowsBackgroundLocationUpdates = false
        isTracking = false
        onUpdate = nil
    }

    public func getLocation() -> AsyncValue<CLLocation> {
        if manager?.authorizationStatus == .denied {
            return .failure(AppError.location(.permissionDenied("位置情報の利用が許可されていません。")))
        }
        if !CLLocationManager.locationServicesEnabled() {
            return .failure(AppError.location(.servicesDisabled("位置情報サービスが無効です。")))
        }
        
        return value
    }

    public func isPermissionAllowed() -> Bool {
        return manager?.authorizationStatus != .denied
    }

    private func updateValue(_ newValue: AsyncValue<CLLocation>) {
        self.value = newValue
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    public nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task{
            await  updateValue(.success(location))
            await onUpdate?(.success(location))
        }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task{ await updateValue(.failure(error)) }
    }
}
