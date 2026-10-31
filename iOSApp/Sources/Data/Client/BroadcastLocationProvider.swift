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
    func requestPermission(onAlwaysAuthorizationRequest: @escaping @Sendable () async -> Void) async
    func authorizationStatus() async -> CLAuthorizationStatus
    func startTracking(onUpdate: ((AsyncValue<CLLocation>) async -> Void)?) async
    func stopTracking() async
    func getLocation() async -> AsyncValue<CLLocation>
    func isAlwaysAuthorized() async -> Bool
    func isLocationServicesEnabled() async -> Bool
    var isTracking: Bool { get async }
}

// MARK: - BroadcastLocationProvider
actor BroadcastLocationProvider: NSObject, BroadcastLocationProviderProtocol {
    private(set) var manager: CLLocationManager?
    private(set) var isTracking = false
    private(set) var value: AsyncValue<CLLocation> = .loading
    private(set) var onUpdate: ((AsyncValue<CLLocation>) async -> Void)?
    private var shouldRequestAlwaysAuthorizationAfterWhenInUse = false
    private var onAlwaysAuthorizationRequest: (@Sendable () async -> Void)?

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
            manager.allowsBackgroundLocationUpdates = true
            if #available(iOS 11.0, *) {
                manager.showsBackgroundLocationIndicator = true
            }
            return manager
        }
        self.manager = manager
    }

    func requestPermission(
        onAlwaysAuthorizationRequest: @escaping @Sendable () async -> Void
    ) async {
        await setupLocationManagerIfNeeded()
        self.onAlwaysAuthorizationRequest = onAlwaysAuthorizationRequest
        switch await authorizationStatusValue() {
        case .authorizedAlways:
            return
        case .authorizedWhenInUse:
            await requestAlwaysAuthorization()
        case .notDetermined:
            shouldRequestAlwaysAuthorizationAfterWhenInUse = true
            let manager = self.manager
            await MainActor.run {
                manager?.requestWhenInUseAuthorization()
            }
        case .restricted, .denied:
            return
        @unknown default:
            return
        }
    }

    func authorizationStatus() async -> CLAuthorizationStatus {
        await setupLocationManagerIfNeeded()
        return await authorizationStatusValue()
    }

    func startTracking(onUpdate: ((AsyncValue<CLLocation>) async -> Void)?) async {
        await setupLocationManagerIfNeeded()
        guard await authorizationStatusValue() == .authorizedAlways else {
            value = .failure(LocationError.authorizationDenied)
            isTracking = false
            return
        }
        guard await locationServicesEnabledValue() else {
            value = .failure(LocationError.servicesDisabled)
            isTracking = false
            return
        }
        value = .loading
        if self.onUpdate == nil, onUpdate != nil {
            self.onUpdate = onUpdate
        }
        let manager = self.manager
        await MainActor.run {
            manager?.startUpdatingLocation()
            manager?.requestLocation()
        }
        isTracking = true

        if let cached = manager?.location {
            value = .success(cached)
        }
    }

    func stopTracking() async {
        let manager = self.manager
        await MainActor.run {
            manager?.stopUpdatingLocation()
        }
        isTracking = false
        onUpdate = nil
    }

    func getLocation() async -> AsyncValue<CLLocation> {
        if await authorizationStatusValue() != .authorizedAlways {
            return .failure(LocationError.authorizationDenied)
        }
        if !(await locationServicesEnabledValue()) {
            return .failure(LocationError.servicesDisabled)
        }
        return value
    }

    func isAlwaysAuthorized() async -> Bool {
        await authorizationStatusValue() == .authorizedAlways
    }

    func isLocationServicesEnabled() async -> Bool {
        await locationServicesEnabledValue()
    }

    private func authorizationStatusValue() async -> CLAuthorizationStatus {
        let manager = self.manager
        return await MainActor.run {
            manager?.authorizationStatus ?? .notDetermined
        }
    }

    private func locationServicesEnabledValue() async -> Bool {
        await MainActor.run {
            CLLocationManager.locationServicesEnabled()
        }
    }

    private func updateValue(_ newValue: AsyncValue<CLLocation>) {
        self.value = newValue
    }

    private func requestAlwaysAuthorization() async {
        await onAlwaysAuthorizationRequest?()
        let manager = self.manager
        await MainActor.run {
            manager?.requestAlwaysAuthorization()
        }
    }

    private func authorizationDidChange(to status: CLAuthorizationStatus) async {
        switch status {
        case .authorizedWhenInUse:
            guard shouldRequestAlwaysAuthorizationAfterWhenInUse else { return }
            shouldRequestAlwaysAuthorizationAfterWhenInUse = false
            await requestAlwaysAuthorization()
        case .authorizedAlways, .notDetermined, .restricted, .denied:
            shouldRequestAlwaysAuthorizationAfterWhenInUse = false
        @unknown default:
            shouldRequestAlwaysAuthorizationAfterWhenInUse = false
        }
    }
}

extension BroadcastLocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task {
            await authorizationDidChange(to: manager.authorizationStatus)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task {
            await updateValue(.success(location))
            await onUpdate?(.success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError, error.code == .locationUnknown {
            // 位置情報がまだ確定していない時の一時通知。後続の成功通知を待つ。
            return
        }
        Task {
            await updateValue(.failure(error))
            await onUpdate?(.failure(error))
        }
    }
}

extension BroadcastLocationProviderProtocol {
    func requestPermission() async {
        await requestPermission(onAlwaysAuthorizationRequest: {})
    }

    func startTracking(onUpdate: ((AsyncValue<CLLocation>) async -> Void)? = nil) async {
        await startTracking(onUpdate: onUpdate)
    }
}
