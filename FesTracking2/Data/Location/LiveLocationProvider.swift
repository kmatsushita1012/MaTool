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
    private let manager: CLLocationManager
    private var delegateProxy: DelegateProxy?
    private(set) var isTracking = false
    private(set) var value: AsyncValue<CLLocation> = .loading

    override init() {
        self.manager = CLLocationManager()
        super.init()
        self.delegateProxy = DelegateProxy(owner: self)
        self.manager.delegate = delegateProxy
        self.manager.allowsBackgroundLocationUpdates = true
    }

    // 権限リクエスト
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
        manager.requestAlwaysAuthorization()
    }

    // トラッキング開始
    func startTracking() {
        manager.startUpdatingLocation()
        isTracking = true
        
        if let cached = manager.location {
            value = .success(cached)
        }
    }

    // トラッキング停止
    func stopTracking() {
        manager.stopUpdatingLocation()
        isTracking = false
    }

    // 最新の状態を返す
    func getLocation() -> AsyncValue<CLLocation> {
        if manager.authorizationStatus == .denied {
            return .failure(LocationError.authorizationDenied)
        }
        if !CLLocationManager.locationServicesEnabled() {
            return .failure(LocationError.servicesDisabled)
        }
        
        return value
    }

    func isPermissionAllowed() -> Bool {
        return manager.authorizationStatus != .denied
    }
    
    private final class DelegateProxy: NSObject, CLLocationManagerDelegate {
        weak var owner: LocationProvider?

        init(owner: LocationProvider) {
            self.owner = owner
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }
            Task { await owner?.updateValue(.success(location)) }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            Task { await owner?.updateValue(.failure(error)) }
        }
    }

    private func updateValue(_ newValue: AsyncValue<CLLocation>) {
        self.value = newValue
    }
}
