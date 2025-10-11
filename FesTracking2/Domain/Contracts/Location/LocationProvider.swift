//
//  LocationProvider.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/18.
//

import Dependencies
import CoreLocation

protocol LocationProviderProtocol:Sendable {
    func requestPermission() async -> Void
    func startTracking(backgroundUpdatesAllowed: Bool, onUpdate: ( @Sendable (AsyncValue<Coordinate>) async -> Void)?) async -> Void
    func stopTracking() async -> Void
    func getLocation() async -> AsyncValue<Coordinate>
    func isPermissionAllowed() async -> Bool
    var isTracking: Bool { get async }
}

extension LocationProviderProtocol {
    func startTracking(backgroundUpdatesAllowed: Bool, onUpdate: ( @Sendable (AsyncValue<Coordinate>) async -> Void)? = nil) async -> Void {
        await startTracking(backgroundUpdatesAllowed: backgroundUpdatesAllowed, onUpdate: onUpdate)
    }
}

struct LocationProviderKey: Sendable{}

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
