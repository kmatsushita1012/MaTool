//
//  Location.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/18.
//

@preconcurrency import CoreLocation
import Combine
import ComposableArchitecture

actor LocationProvider: NSObject, LocationProviderProtocol {
    private(set) var manager: CLLocationManager? = nil
    private(set) var isTracking = false
    private(set) var value: AsyncValue<Coordinate> = .loading
    private(set) var onUpdate: ( @Sendable (AsyncValue<Coordinate>) async ->Void)? = nil

    override init() {
        super.init()
        manager?.pausesLocationUpdatesAutomatically = false
        Task{
            await setupLocationManagerIfNeeded()
        }
    }
    
    private func setupLocationManagerIfNeeded() async {
        let manager = await MainActor.run {
            let manager = CLLocationManager()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.pausesLocationUpdatesAutomatically = true
            return manager
        }
        if self.manager == nil {
            self.manager = manager
        }
        
    }

    // 権限リクエスト
    func requestPermission() async {
        await setupLocationManagerIfNeeded()
        manager?.requestWhenInUseAuthorization()
        manager?.requestAlwaysAuthorization()
    }

    // トラッキング開始
    func startTracking(backgroundUpdatesAllowed: Bool, onUpdate: ( @Sendable (AsyncValue<Coordinate>) async -> Void)?) {
        if backgroundUpdatesAllowed {
            manager?.allowsBackgroundLocationUpdates = true
        }
        if self.onUpdate == nil, onUpdate != nil{
            self.onUpdate = onUpdate
        }
        manager?.startUpdatingLocation()
        isTracking = true
        
        if let cached = manager?.location {
            let coordinate = Coordinate(
                latitude: cached.coordinate.latitude,
                longitude: cached.coordinate.longitude
            )
            value = .success(coordinate)
        }
    }

    // トラッキング停止
    func stopTracking() {
        manager?.stopUpdatingLocation()
        manager?.allowsBackgroundLocationUpdates = false
        isTracking = false
        onUpdate = nil
    }

    // 最新の状態を返す
    func getLocation() -> AsyncValue<Coordinate> {
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

    private func updateValue(_ newValue: AsyncValue<Coordinate>) {
        self.value = newValue
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task{
            let coordinate = Coordinate.fromCL(location.coordinate)
            await updateValue(.success(coordinate))
            await onUpdate?(.success(coordinate))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task{ await updateValue(.failure(error)) }
    }
}
