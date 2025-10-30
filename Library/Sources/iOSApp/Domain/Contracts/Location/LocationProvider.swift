//
//  LocationProvider.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/18.
//

import Dependencies
import CoreLocation

protocol LocationProviderProtocol {
    func requestPermission() async -> Void
    func startTracking(backgroundUpdatesAllowed: Bool, onUpdate: ((AsyncValue<CLLocation>) async -> Void)?) async -> Void
    func stopTracking() async -> Void
    func getLocation() async -> AsyncValue<CLLocation>
    func isPermissionAllowed() async -> Bool
    var isTracking: Bool { get async }
}

extension LocationProviderProtocol {
    func startTracking(backgroundUpdatesAllowed: Bool, onUpdate: ((AsyncValue<CLLocation>) async -> Void)? = nil) async -> Void {
        await startTracking(backgroundUpdatesAllowed: backgroundUpdatesAllowed, onUpdate: onUpdate)
    }
}

struct LocationProviderKey{}

extension LocationProviderKey: DependencyKey{
    static let liveValue: LocationProviderProtocol = LocationProvider()
}

extension LocationProviderKey: TestDependencyKey {
    static let testValue: LocationProviderProtocol = LocationProvider() // 仮
}

extension DependencyValues {
    var locationProvider: LocationProviderProtocol {
        get { self[LocationProviderKey.self] }
        set { self[LocationProviderKey.self] = newValue }
    }
}

enum LocationError: Error {
    case authorizationDenied
    case servicesDisabled
}
