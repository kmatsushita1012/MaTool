//
//  MapLocationProvider.swift
//  MaTool
//
//  Created by Codex on 2026/03/21.
//

import Dependencies
import CoreLocation

// MARK: - Dependencies
enum MapLocationProviderKey: DependencyKey {
    static let liveValue: MapLocationProviderProtocol = MapLocationProvider()
}

extension DependencyValues {
    var mapLocationProvider: MapLocationProviderProtocol {
        get { self[MapLocationProviderKey.self] }
        set { self[MapLocationProviderKey.self] = newValue }
    }
}

// MARK: - MapLocationProviderProtocol
protocol MapLocationProviderProtocol: Sendable {
    func requestPermission() async
    func startTracking() async
    func stopTracking() async
    func getLocation() async -> AsyncValue<CLLocation>
    var isTracking: Bool { get async }
}

// MARK: - MapLocationProvider
actor MapLocationProvider: NSObject, MapLocationProviderProtocol {
    private(set) var manager: CLLocationManager?
    private(set) var isTracking = false
    private(set) var value: AsyncValue<CLLocation> = .loading

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
            manager.pausesLocationUpdatesAutomatically = true
            manager.allowsBackgroundLocationUpdates = false
            return manager
        }
        self.manager = manager
    }

    func requestPermission() async {
        await setupLocationManagerIfNeeded()
        manager?.requestWhenInUseAuthorization()
    }

    func startTracking() async {
        await setupLocationManagerIfNeeded()
        manager?.startUpdatingLocation()
        isTracking = true

        if let cached = manager?.location {
            value = .success(cached)
        }
    }

    func stopTracking() async {
        manager?.stopUpdatingLocation()
        isTracking = false
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

    private func updateValue(_ newValue: AsyncValue<CLLocation>) {
        self.value = newValue
    }
}

extension MapLocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { await updateValue(.success(location)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { await updateValue(.failure(error)) }
    }
}
