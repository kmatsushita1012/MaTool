//
//  Location.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/18.
//

import CoreLocation
import Combine
import ComposableArchitecture

actor LocationProvider: NSObject, LocationProviderProtocol {
    private(set) var manager: CLLocationManager? = nil
    private(set) var isTracking = false
    private(set) var value: AsyncValue<CLLocation> = .loading

    private var continuation: AsyncStream<CLLocation>.Continuation?
    
    override init() {
        super.init()
        manager?.pausesLocationUpdatesAutomatically = false
        Task{
            await setupLocationManagerIfNeeded()
        }
    }
    
    var locations: AsyncStream<CLLocation> {
       AsyncStream { continuation in
           self.continuation = continuation
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
    func startTracking(backgroundUpdatesAllowed: Bool) {
        if backgroundUpdatesAllowed {
            manager?.allowsBackgroundLocationUpdates = true
        }
        manager?.startUpdatingLocation()
        isTracking = true
        
        if let cached = manager?.location {
            value = .success(cached)
            continuation?.yield(cached)
        }
    }

    // トラッキング停止
    func stopTracking() {
        manager?.stopUpdatingLocation()
        manager?.allowsBackgroundLocationUpdates = false
        isTracking = false
        continuation?.finish()
    }

    // 最新の状態を返す
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
        Task {
            await updateValue(.success(location))
            await continuation?.yield(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task{ await updateValue(.failure(error)) }
    }
}
