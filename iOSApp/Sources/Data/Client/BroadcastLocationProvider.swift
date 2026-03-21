//
//  BroadcastLocationProvider.swift
//  MaTool
//
//  Created by Codex on 2026/03/21.
//

import Dependencies
import CoreLocation

// MARK: - Dependencies
enum BroadcastLocationProviderKey: DependencyKey {
    static let liveValue: BroadcastLocationProviderProtocol = BroadcastLocationProvider()
}

extension DependencyValues {
    var broadcastLocationProvider: BroadcastLocationProviderProtocol {
        get { self[BroadcastLocationProviderKey.self] }
        set { self[BroadcastLocationProviderKey.self] = newValue }
    }
}

// MARK: - BroadcastLocationProviderProtocol
protocol BroadcastLocationProviderProtocol: Sendable {
    func requestPermission() async
    func startTracking(onUpdate: ((AsyncValue<CLLocation>) async -> Void)?) async
    func stopTracking() async
    func getLocation() async -> AsyncValue<CLLocation>
    func isAlwaysAuthorized() async -> Bool
    var isTracking: Bool { get async }
}

// MARK: - BroadcastLocationProvider
actor BroadcastLocationProvider: NSObject, BroadcastLocationProviderProtocol {
    private(set) var manager: CLLocationManager?
    private(set) var isTracking = false
    private(set) var value: AsyncValue<CLLocation> = .loading
    private(set) var onUpdate: ((AsyncValue<CLLocation>) async -> Void)?

    override init() {
        super.init()
        Task {
            await setupLocationManagerIfNeeded()
        }
    }

    private func setupLocationManagerIfNeeded() async {
        guard manager == nil else { return }
        let manager = await MainActor.run {
            let manager = CLLocationManager()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.distanceFilter = kCLDistanceFilterNone
            manager.activityType = .fitness
            manager.pausesLocationUpdatesAutomatically = false
            if #available(iOS 11.0, *) {
                manager.showsBackgroundLocationIndicator = true
            }
            return manager
        }
        self.manager = manager
    }

    func requestPermission() async {
        await setupLocationManagerIfNeeded()
        manager?.requestWhenInUseAuthorization()
        manager?.requestAlwaysAuthorization()
    }

    func startTracking(onUpdate: ((AsyncValue<CLLocation>) async -> Void)?) async {
        await setupLocationManagerIfNeeded()
        manager?.allowsBackgroundLocationUpdates = true
        if self.onUpdate == nil, onUpdate != nil {
            self.onUpdate = onUpdate
        }
        manager?.startUpdatingLocation()
        isTracking = true

        if let cached = manager?.location {
            value = .success(cached)
        }
    }

    func stopTracking() async {
        manager?.stopUpdatingLocation()
        manager?.allowsBackgroundLocationUpdates = false
        isTracking = false
        onUpdate = nil
    }

    func getLocation() async -> AsyncValue<CLLocation> {
        if manager?.authorizationStatus == .denied {
            return .failure(LocationError.authorizationDenied)
        }
        if !CLLocationManager.locationServicesEnabled() {
            return .failure(LocationError.servicesDisabled)
        }
        return value
    }

    func isAlwaysAuthorized() async -> Bool {
        let status = manager?.authorizationStatus
        return status == .authorizedAlways
    }

    private func updateValue(_ newValue: AsyncValue<CLLocation>) {
        self.value = newValue
    }
}

extension BroadcastLocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task {
            await updateValue(.success(location))
            await onUpdate?(.success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task {
            await updateValue(.failure(error))
            await onUpdate?(.failure(error))
        }
    }
}

extension BroadcastLocationProviderProtocol {
    func startTracking(onUpdate: ((AsyncValue<CLLocation>) async -> Void)? = nil) async {
        await startTracking(onUpdate: onUpdate)
    }
}

